import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:myeye/core/camera/camera_session.dart';
import 'package:myeye/core/camera/input_frame.dart';
import 'package:myeye/core/permissions/permission_service.dart';
import 'package:myeye/features/obstacle/models/obstacle_ui_state.dart';
import 'package:myeye/features/obstacle/services/coco_obstacle_filter_service.dart';
import 'package:myeye/features/obstacle/services/coco_obstacle_warning_service.dart';
import 'package:myeye/features/obstacle/services/obstacle_alert_memory_service.dart';
import 'package:myeye/features/obstacle/services/obstacle_auto_flash_service.dart';
import 'package:myeye/features/obstacle/services/obstacle_general_object_service.dart';
import 'package:myeye/features/obstacle/services/obstacle_tracking_service.dart';
import 'package:myeye/features/obstacle/services/obstacle_tts_service.dart';

class CocoObstacleController extends ChangeNotifier {
  CocoObstacleController({
    ObstacleGeneralObjectService? inferenceService,
    CocoObstacleFilterService? filterService,
    ObstacleTrackingService? trackingService,
    CocoObstacleWarningService? warningService,
    ObstacleAlertMemoryService? alertMemoryService,
    ObstacleTtsService? ttsService,
    ObstacleAutoFlashService? autoFlashService,
  }) : _inferenceService = inferenceService ?? ObstacleGeneralObjectService(),
       _filterService = filterService ?? CocoObstacleFilterService(),
       _trackingService = trackingService ?? ObstacleTrackingService(),
       _warningService = warningService ?? CocoObstacleWarningService(),
       _alertMemoryService = alertMemoryService ?? ObstacleAlertMemoryService(),
       _ttsService = ttsService ?? ObstacleTtsService(),
       _autoFlashService = autoFlashService ?? ObstacleAutoFlashService();

  static const int frameIntervalMs = 650;

  final ObstacleGeneralObjectService _inferenceService;
  final CocoObstacleFilterService _filterService;
  final ObstacleTrackingService _trackingService;
  final CocoObstacleWarningService _warningService;
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

  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFallbackGuide = DateTime.fromMillisecondsSinceEpoch(0);

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
      await _inferenceService.init();

      if (_disposed || _closing) return;

      _setUiState(
        _uiState.copyWith(
          canStartCamera: true,
          scanning: false,
          status: 'جاهز',
          guide: 'اضغط مرتين أو قل تصوير لبدء اختبار كوكو',
          label: '—',
          confidence: 0.0,
          debug: 'debug: COCO model loaded in background isolate',
          detections: const [],
          clearWarning: true,
        ),
      );

      await _ttsService.speakIntro(
        'تم فتح اختبار كوكو. للتشغيل اضغط مرتين أو قل تصوير. للإغلاق اضغط مرتين أثناء التشغيل.',
      );
    } catch (error) {
      if (_disposed || _closing) return;

      _setUiState(
        _uiState.copyWith(
          canStartCamera: false,
          scanning: false,
          status: 'خطأ تحميل موديل كوكو',
          guide: 'راجع ملف الموديل ومساره في assets',
          debug: 'debug: COCO model load error: $error',
          clearWarning: true,
        ),
      );

      await _ttsService.speakIntro('حصل خطأ في تحميل موديل كوكو.');
    }
  }

  void attachSession(CameraSessionController? session) {
    if (_disposed || _closing) return;

    _session = session;
  }

  Future<void> toggleScanning() async {
    if (_disposed || _closing) return;

    if (!_uiState.canStartCamera || !_inferenceService.isReady) {
      await _ttsService.speakGuide('موديل كوكو غير جاهز بعد.');
      return;
    }

    await _ttsService.stop();

    final next = !_uiState.scanning;

    _trackingService.reset();
    _warningService.reset();
    _alertMemoryService.reset();
    _lastFallbackGuide = DateTime.fromMillisecondsSinceEpoch(0);

    _setUiState(
      _uiState.copyWith(
        scanning: next,
        status: next ? 'يعمل الآن' : 'متوقف',
        label: '—',
        confidence: 0.0,
        guide: next
            ? 'جاري فحص الأشياء أمامك'
            : 'اضغط مرتين أو قل تصوير لبدء اختبار كوكو',
        debug: next
            ? 'debug: COCO scanning started'
            : 'debug: COCO scanning stopped',
        detections: const [],
        clearWarning: true,
      ),
    );

    if (!next) {
      await _autoFlashService.turnOff(_session);
    }

    if (_disposed || _closing) return;

    await _ttsService.speakIntro(
      next ? 'تم بدء اختبار كوكو.' : 'تم إيقاف اختبار كوكو.',
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
          debug: 'debug: closing COCO screen safely',
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
    if (!_inferenceService.isReady) return;

    final now = DateTime.now();

    if (now.difference(_lastRun).inMilliseconds < frameIntervalMs) return;
    if (_processing) return;

    _processing = true;
    _lastRun = now;

    final stopwatch = Stopwatch()..start();

    try {
      await _autoFlashService.updateFromFrame(frame: frame, session: _session);

      if (_disposed || _closing || !_uiState.scanning) return;

      final cocoDetections = await _inferenceService.detectFromFrame(frame);

      if (_disposed || _closing || !_uiState.scanning) return;

      final visibleDetections = _filterService
          .toObstacleDetections(cocoDetections)
          .take(8)
          .toList();

      final best = _filterService.chooseBest(cocoDetections);

      stopwatch.stop();

      if (best == null) {
        _trackingService.reset();
        _alertMemoryService.markNoCandidate();

        _setUiState(
          _uiState.copyWith(
            status: 'فحص الأشياء',
            label: '—',
            confidence: 0.0,
            guide: 'لا يوجد عائق مؤكد من كوكو',
            debug:
                'debug: cocoRaw=${cocoDetections.length} | accepted=none | ${stopwatch.elapsedMilliseconds}ms',
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
          status: track.locked ? 'تحذير مؤكد' : 'جاري التأكيد',
          label: labelText,
          confidence: best.detection.confidence,
          guide: track.locked
              ? warning.shortText
              : 'تثبيت ${best.profile.arabicName} ${track.hits}/${track.requiredHits}',
          warning: track.locked ? warning : null,
          clearWarning: !track.locked,
          detections: visibleDetections,
          debug:
              'debug: cocoRaw=${cocoDetections.length} | '
              'accepted=${best.profile.modelLabel} '
              '${(best.detection.confidence * 100).toStringAsFixed(1)}% | '
              'track=${track.hits}/${track.requiredHits} | '
              'dir=${best.direction.name} | '
              'dist=${best.distance.name} | '
              'area=${best.detection.area.toStringAsFixed(3)} | '
              'bottom=${best.detection.bottom.toStringAsFixed(2)} | '
              'speech=${alertDecision.shouldSpeak ? "yes" : "no"} | '
              'reason=${alertDecision.reason} | '
              '${stopwatch.elapsedMilliseconds}ms',
        ),
      );

      if (_disposed || _closing) return;
      if (!track.locked) return;
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
          status: 'خطأ أثناء تحليل كوكو',
          guide: 'راجع Debug',
          debug:
              'debug: COCO frame error: $error | ${stopwatch.elapsedMilliseconds}ms',
        ),
      );
    } finally {
      _processing = false;
    }
  }

  void _speakFallbackGuide() {
    if (_disposed || _closing) return;

    final now = DateTime.now();

    if (now.difference(_lastFallbackGuide).inMilliseconds < 12000) return;

    _lastFallbackGuide = now;

    unawaited(_ttsService.speakGuide('جاري فحص الأشياء أمامك.'));
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
      _inferenceService.dispose();
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
