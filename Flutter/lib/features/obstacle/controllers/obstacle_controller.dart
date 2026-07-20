import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:myeye/core/camera/camera_session.dart';
import 'package:myeye/core/camera/input_frame.dart';
import 'package:myeye/core/permissions/permission_service.dart';
import 'package:myeye/features/obstacle/models/obstacle_detection_result.dart';
import 'package:myeye/features/obstacle/models/obstacle_label.dart';
import 'package:myeye/features/obstacle/models/obstacle_ui_state.dart';
import 'package:myeye/features/obstacle/services/coco_obstacle_filter_service.dart';
import 'package:myeye/features/obstacle/services/custom_special_obstacle_filter_service.dart';
import 'package:myeye/features/obstacle/services/hybrid_obstacle_fusion_service.dart';
import 'package:myeye/features/obstacle/services/obstacle_alert_memory_service.dart';
import 'package:myeye/features/obstacle/services/obstacle_auto_flash_service.dart';
import 'package:myeye/features/obstacle/services/obstacle_general_object_service.dart';
import 'package:myeye/features/obstacle/services/obstacle_filter_service.dart';
import 'package:myeye/features/obstacle/services/obstacle_inference_service.dart';
import 'package:myeye/features/obstacle/services/obstacle_tracking_service.dart';
import 'package:myeye/features/obstacle/services/obstacle_tts_service.dart';
import 'package:myeye/features/obstacle/services/obstacle_warning_service.dart';

class ObstacleController extends ChangeNotifier {
  ObstacleController({
    ObstacleGeneralObjectService? cocoInferenceService,
    ObstacleInferenceService? customInferenceService,
    CocoObstacleFilterService? cocoFilterService,
    CustomSpecialObstacleFilterService? customSpecialFilterService,
    HybridObstacleFusionService? fusionService,
    ObstacleTrackingService? trackingService,
    ObstacleWarningService? warningService,
    ObstacleAlertMemoryService? alertMemoryService,
    ObstacleTtsService? ttsService,
    ObstacleAutoFlashService? autoFlashService,
  }) : _cocoInferenceService =
           cocoInferenceService ?? ObstacleGeneralObjectService(),
       _customInferenceService =
           customInferenceService ??
           ObstacleInferenceService(confidenceThreshold: 0.24),
       _cocoFilterService = cocoFilterService ?? CocoObstacleFilterService(),
       _customSpecialFilterService =
           customSpecialFilterService ?? CustomSpecialObstacleFilterService(),
       _fusionService = fusionService ?? const HybridObstacleFusionService(),
       _trackingService = trackingService ?? ObstacleTrackingService(),
       _warningService = warningService ?? ObstacleWarningService(),
       _alertMemoryService = alertMemoryService ?? ObstacleAlertMemoryService(),
       _ttsService = ttsService ?? ObstacleTtsService(),
       _autoFlashService = autoFlashService ?? ObstacleAutoFlashService();

  static const int frameIntervalMs = 320;
  static const int customModelIntervalMs = 520;
  static const int customCandidateCacheMs = 1650;

  final ObstacleGeneralObjectService _cocoInferenceService;
  final ObstacleInferenceService _customInferenceService;
  final CocoObstacleFilterService _cocoFilterService;
  final CustomSpecialObstacleFilterService _customSpecialFilterService;
  final HybridObstacleFusionService _fusionService;
  final ObstacleTrackingService _trackingService;
  final ObstacleWarningService _warningService;
  final ObstacleAlertMemoryService _alertMemoryService;
  final ObstacleTtsService _ttsService;
  final ObstacleAutoFlashService _autoFlashService;

  ObstacleUiState _uiState = ObstacleUiState.initial();

  ObstacleUiState get uiState => _uiState;

  CameraSessionController? _session;

  bool _disposed = false;
  bool _closing = false;
  bool _processing = false;
  bool _resourcesReleased = false;
  bool _customModelReady = false;

  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastCustomRun = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastCustomCacheAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFallbackGuide = DateTime.fromMillisecondsSinceEpoch(0);

  List<ObstacleDetectionResult> _cachedCustomVisibleDetections = const [];
  List<ObstacleCandidate> _cachedCustomCandidates = const [];

  String _lastCustomDebug = 'custom:not-run-yet';

  Future<void> init() async {
    if (_disposed || _closing) return;

    await _ttsService.init();

    if (_disposed || _closing) return;

    final hasCameraPermission = await PermissionService.ensureCameraPermission(
      speak: _ttsService.speakIntro,
    );

    if (_disposed || _closing) return;

    if (!hasCameraPermission) {
      _setUiState(
        _uiState.copyWith(
          canStartCamera: false,
          status: 'محتاج إذن الكاميرا',
          guide: 'اسمح بإذن الكاميرا من الإعدادات',
          debug: 'debug: camera permission denied',
          clearWarning: true,
        ),
      );

      await _ttsService.speakIntro('من فضلك اسمح بإذن الكاميرا.');
      return;
    }

    try {
      await _cocoInferenceService.init();

      try {
        await _customInferenceService.init();
        _customModelReady = true;
        _lastCustomDebug = 'custom:ready';
      } catch (customError) {
        _customModelReady = false;
        _lastCustomDebug = 'custom:load-error:$customError';
      }

      if (_disposed || _closing) return;

      _setUiState(
        _uiState.copyWith(
          canStartCamera: true,
          scanning: false,
          status: _customModelReady ? 'جاهز' : 'جاهز بكوكو فقط',
          guide: 'اضغط مرتين أو قل تصوير لبدء كشف العوائق',
          label: '—',
          confidence: 0.0,
          debug: _customModelReady
              ? 'debug: hybrid ready | coco=main | custom=stairs,pothole,opened-door'
              : 'debug: hybrid ready | coco=main | $_lastCustomDebug',
          detections: const [],
          clearWarning: true,
        ),
      );

      await _ttsService.speakIntro(
        'تم فتح كاميرا كشف العوائق. للتشغيل اضغط مرتين أو قل تصوير. للإغلاق اضغط مرتين أو اضغط زر الخروج أعلا الشاشه يسارا.',
      );
    } catch (error) {
      if (_disposed || _closing) return;

      _setUiState(
        _uiState.copyWith(
          canStartCamera: false,
          scanning: false,
          status: 'خطأ تحميل موديل العوائق',
          guide: 'راجع ملفات الموديلات ومساراتها في assets',
          debug: 'debug: hybrid load error: $error',
          clearWarning: true,
        ),
      );

      await _ttsService.speakIntro('حصل خطأ في تحميل موديل العوائق.');
    }
  }

  void attachSession(CameraSessionController? session) {
    if (_disposed || _closing) return;

    _session = session;
  }

  Future<void> toggleScanning() async {
    if (_disposed || _closing) return;

    if (!_uiState.canStartCamera || !_cocoInferenceService.isReady) {
      await _ttsService.speakGuide('كشف العوائق غير جاهز بعد.');
      return;
    }

    await _ttsService.stop();

    final next = !_uiState.scanning;

    _trackingService.reset();
    _warningService.reset();
    _alertMemoryService.reset();
    _cachedCustomCandidates = const [];
    _cachedCustomVisibleDetections = const [];
    _lastCustomRun = DateTime.fromMillisecondsSinceEpoch(0);
    _lastCustomCacheAt = DateTime.fromMillisecondsSinceEpoch(0);
    _lastFallbackGuide = DateTime.fromMillisecondsSinceEpoch(0);

    _setUiState(
      _uiState.copyWith(
        scanning: next,
        status: next ? 'يعمل الآن' : 'متوقف',
        label: '—',
        confidence: 0.0,
        guide: next
            ? 'جاري فحص الطريق أمامك'
            : 'اضغط مرتين أو قل تصوير لبدء كشف العوائق',
        debug: next
            ? 'debug: hybrid scanning started'
            : 'debug: hybrid scanning stopped',
        detections: const [],
        clearWarning: true,
      ),
    );

    if (!next) {
      await _autoFlashService.turnOff(_session);
    }

    if (_disposed || _closing) return;

    await _ttsService.speakIntro(
      next ? 'تم بدء كشف العوائق.' : 'تم إيقاف كشف العوائق.',
    );
  }

  Future<void> closeForExit() async {
    if (_disposed) return;

    if (!_closing) {
      _closing = true;

      _setUiState(
        _uiState.copyWith(
          scanning: false,
          status: 'جارٍ الرجوع',
          guide: 'جاري الرجوع للشاشة الرئيسية',
          label: '—',
          confidence: 0.0,
          debug: 'debug: closing obstacle screen safely',
          detections: const [],
          clearWarning: true,
        ),
      );
    }

    await _releaseRuntimeResources();
  }

  Future<void> onFrame(InputFrame frame) async {
    if (_disposed || _closing) return;
    if (!_uiState.canStartCamera || !_uiState.scanning) return;
    if (!_cocoInferenceService.isReady) return;

    final now = DateTime.now();

    if (now.difference(_lastRun).inMilliseconds < frameIntervalMs) return;
    if (_processing) return;

    _processing = true;
    _lastRun = now;

    final stopwatch = Stopwatch()..start();

    try {
      await _autoFlashService.updateFromFrame(frame: frame, session: _session);

      if (_disposed || _closing || !_uiState.scanning) return;

      final cocoDetections = await _cocoInferenceService.detectFromFrame(frame);

      if (_disposed || _closing || !_uiState.scanning) return;

      final cocoCandidates = _cocoFilterService.candidatesFrom(cocoDetections);
      final cocoVisibleDetections = _cocoFilterService
          .toObstacleDetections(cocoDetections)
          .take(8)
          .toList();

      await _updateCustomCacheIfNeeded(frame, now);

      if (_disposed || _closing || !_uiState.scanning) return;

      final customCacheStillFresh =
          now.difference(_lastCustomCacheAt).inMilliseconds <=
          customCandidateCacheMs;

      final customCandidates = customCacheStillFresh
          ? _cachedCustomCandidates
          : const <ObstacleCandidate>[];

      final customVisibleDetections = customCacheStillFresh
          ? _cachedCustomVisibleDetections
          : const <ObstacleDetectionResult>[];

      final visibleDetections = <ObstacleDetectionResult>[
        ..._prioritizeVisibleDetections(cocoVisibleDetections),
        ...customVisibleDetections,
      ].take(8).toList();

      final best = _fusionService.chooseBest(
        cocoCandidates: cocoCandidates,
        customCandidates: customCandidates,
      );

      stopwatch.stop();

      if (best == null) {
        _trackingService.reset();
        _alertMemoryService.markNoCandidate();

        _setUiState(
          _uiState.copyWith(
            status: 'فحص الطريق',
            label: '—',
            confidence: 0.0,
            guide: 'لا يوجد عائق مؤكد',
            debug:
                'debug: cocoRaw=${cocoDetections.length} | '
                'cocoAccepted=${cocoCandidates.length} | '
                'customAccepted=${customCandidates.length} | '
                '$_lastCustomDebug | ${stopwatch.elapsedMilliseconds}ms',
            detections: visibleDetections,
            clearWarning: true,
          ),
        );

        _speakFallbackGuide();
        return;
      }

      final track = _trackingService.update(best);
      final warning = _warningService.buildWarning(best);

      final alertDecision = _alertMemoryService.updateAndDecide(
        candidate: best,
        trackState: track,
        warning: warning,
      );

      final labelText =
          '${best.profile.arabicName} ${(best.detection.confidence * 100).round()}%';

      _setUiState(
        _uiState.copyWith(
          status: 'يراقب الطريق',
          label: labelText,
          confidence: best.detection.confidence,
          guide: warning.shortText,
          warning: warning,
          clearWarning: false,
          detections: visibleDetections,
          debug:
              'debug: source=${best.reason} | '
              'cocoRaw=${cocoDetections.length} | '
              'cocoAccepted=${cocoCandidates.length} | '
              'customAccepted=${customCandidates.length} | '
              'accepted=${best.profile.modelLabel} '
              '${(best.detection.confidence * 100).toStringAsFixed(1)}% | '
              'track=instant | '
              'dir=${best.direction.name} | '
              'dist=${best.distance.name} | '
              'area=${best.detection.area.toStringAsFixed(3)} | '
              'bottom=${best.detection.bottom.toStringAsFixed(2)} | '
              'speech=${alertDecision.shouldSpeak ? "yes" : "no"} | '
              'reason=${alertDecision.reason} | '
              '$_lastCustomDebug | ${stopwatch.elapsedMilliseconds}ms',
        ),
      );

      if (_disposed || _closing) return;
      if (!alertDecision.shouldSpeak) return;

      if (alertDecision.shouldVibrate) {
        unawaited(HapticFeedback.heavyImpact());
      }

      await _ttsService.speakWarning(warning.speechText);
    } catch (error) {
      stopwatch.stop();

      if (_disposed || _closing) return;

      _setUiState(
        _uiState.copyWith(
          status: 'خطأ أثناء التحليل',
          guide: 'راجع Debug',
          debug:
              'debug: hybrid frame error: $error | ${stopwatch.elapsedMilliseconds}ms',
        ),
      );
    } finally {
      _processing = false;
    }
  }

  Future<void> _updateCustomCacheIfNeeded(
    InputFrame frame,
    DateTime now,
  ) async {
    if (!_customModelReady) return;

    final shouldRunCustom =
        now.difference(_lastCustomRun).inMilliseconds >= customModelIntervalMs;

    if (!shouldRunCustom) return;

    _lastCustomRun = now;

    try {
      final customDetections = await _customInferenceService.detectFromFrame(
        frame,
      );

      final visible = _customSpecialFilterService.visibleDetections(
        customDetections,
      );

      final candidates = _customSpecialFilterService.candidatesFrom(
        customDetections,
      );

      _cachedCustomVisibleDetections = visible.take(4).toList();
      _cachedCustomCandidates = candidates;
      _lastCustomCacheAt = DateTime.now();

      final rawSummary = customDetections
          .take(4)
          .map(
            (detection) =>
                '${detection.rawLabel}:${(detection.confidence * 100).round()}%',
          )
          .join(',');

      _lastCustomDebug =
          'customRaw=${customDetections.length} | '
          'customSpecial=${candidates.length} | '
          'customSeen=${rawSummary.isEmpty ? "none" : rawSummary}';
    } catch (error) {
      _cachedCustomVisibleDetections = const [];
      _cachedCustomCandidates = const [];
      _lastCustomDebug = 'custom:error:$error';
    }
  }

  List<ObstacleDetectionResult> _prioritizeVisibleDetections(
    List<ObstacleDetectionResult> detections,
  ) {
    final copy = [...detections];

    copy.sort((a, b) {
      final aProfile = ObstacleClassProfiles.profileOf(a.label);
      final bProfile = ObstacleClassProfiles.profileOf(b.label);

      final priority = bProfile.priority.compareTo(aProfile.priority);
      if (priority != 0) return priority;

      return b.confidence.compareTo(a.confidence);
    });

    return copy;
  }

  void _speakFallbackGuide() {
    if (_disposed || _closing) return;

    final now = DateTime.now();

    if (now.difference(_lastFallbackGuide).inMilliseconds < 25000) return;

    _lastFallbackGuide = now;

    unawaited(_ttsService.speakGuide('جاري فحص الطريق أمامك.'));
  }

  void _setUiState(ObstacleUiState nextState) {
    if (_disposed) return;

    _uiState = nextState;
    notifyListeners();
  }

  Future<void> _releaseRuntimeResources() async {
    if (_resourcesReleased) return;

    _resourcesReleased = true;
    _processing = false;

    try {
      await _ttsService.stop();
    } catch (_) {}

    try {
      await _autoFlashService.turnOff(_session);
    } catch (_) {}

    try {
      await _session?.stopStream();
    } catch (_) {}

    try {
      _cocoInferenceService.dispose();
    } catch (_) {}

    try {
      _customInferenceService.dispose();
    } catch (_) {}

    try {
      await _ttsService.dispose();
    } catch (_) {}

    _alertMemoryService.reset();
    _trackingService.reset();
    _warningService.reset();

    _session = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _closing = true;
    _processing = false;

    unawaited(_releaseRuntimeResources());

    super.dispose();
  }
}
