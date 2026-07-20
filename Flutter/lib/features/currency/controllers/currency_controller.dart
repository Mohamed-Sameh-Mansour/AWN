import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:myeye/core/camera/camera_session.dart';
import 'package:myeye/core/camera/input_frame.dart';
import 'package:myeye/core/constants/app_constants.dart';
import 'package:myeye/core/permissions/permission_service.dart';
import 'package:myeye/features/currency/models/currency_detection_result.dart';
import 'package:myeye/features/currency/models/currency_session_state.dart';
import 'package:myeye/features/currency/models/currency_ui_state.dart';
import 'package:myeye/features/currency/services/currency_auto_flash_service.dart';
import 'package:myeye/features/currency/services/currency_guidance_service.dart';
import 'package:myeye/features/currency/services/currency_inference_service.dart';
import 'package:myeye/features/currency/services/currency_quick_recognition_tracker.dart';
import 'package:myeye/features/currency/services/currency_stability_tracker.dart';
import 'package:myeye/features/currency/services/currency_tts_service.dart';

class CurrencyController extends ChangeNotifier {
  CurrencyController({
    CurrencyInferenceService? inferenceService,
    CurrencyTtsService? ttsService,
    CurrencyAutoFlashService? autoFlashService,
  }) : _inferenceService = inferenceService ?? CurrencyInferenceService(),
       _ttsService = ttsService ?? CurrencyTtsService(),
       _autoFlashService = autoFlashService ?? CurrencyAutoFlashService();

  final CurrencyInferenceService _inferenceService;
  final CurrencyTtsService _ttsService;
  final CurrencyAutoFlashService _autoFlashService;

  final CurrencyGuidanceService _guidanceService =
      const CurrencyGuidanceService();

  final CurrencyStabilityTracker _stabilityTracker = CurrencyStabilityTracker();

  final CurrencyQuickRecognitionTracker _quickRecognitionTracker =
      CurrencyQuickRecognitionTracker();

  CurrencyUiState _uiState = CurrencyUiState.initial();

  CurrencyUiState get uiState => _uiState;

  CameraSessionController? _session;

  bool _processing = false;
  bool _disposed = false;
  bool _finishingVerification = false;

  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastVerificationAcceptedAt = DateTime.fromMillisecondsSinceEpoch(0);

  String _lastStableLabel = '';

  final List<String> _verificationResults = [];

  int _scanGeneration = 0;

  Future<void> Function()? _pauseVoiceForFinalSpeech;
  Future<void> Function()? _resumeVoiceAfterFinalSpeech;

  void setVoiceLifecycleHooks({
    Future<void> Function()? pauseVoiceForFinalSpeech,
    Future<void> Function()? resumeVoiceAfterFinalSpeech,
  }) {
    _pauseVoiceForFinalSpeech = pauseVoiceForFinalSpeech;
    _resumeVoiceAfterFinalSpeech = resumeVoiceAfterFinalSpeech;
  }

  Future<void> init() async {
    await _ttsService.init();

    if (_disposed) return;

    final hasCameraPermission = await PermissionService.ensureCameraPermission(
      speak: _ttsService.speakFinal,
    );

    if (_disposed) return;

    if (!hasCameraPermission) {
      _setUiState(
        _uiState.copyWith(
          canStartCamera: false,
          status: 'محتاج إذن الكاميرا',
          guide: 'اسمح بإذن الكاميرا من الإعدادات',
          sessionState: CurrencySessionState.idle,
        ),
      );

      await _ttsService.speakFinal('من فضلك اسمح بإذن الكاميرا.');
      return;
    }

    try {
      await _inferenceService.init();

      if (_disposed) return;

      _setUiState(
        _uiState.copyWith(
          canStartCamera: true,
          status: 'جاهز',
          label: '—',
          guide: 'لكشف عملة اضغط مرتين أو قل تصوير',
          confidence: 0.0,
          sessionState: CurrencySessionState.idle,
        ),
      );

      await _ttsService.speakFinal(
        'تم فتح كاميرا العملات. للتشغيل اضغط مرتين أو قل تصوير. وللإغلاق قل إغلاق أو اضغط سهم الخروج أعلا الشاشه يسارا.',
      );
    } catch (_) {
      if (_disposed) return;

      _setUiState(
        _uiState.copyWith(
          canStartCamera: false,
          status: 'خطأ تحميل الموديل',
          guide: 'راجع ملف الموديل والليبلز',
          sessionState: CurrencySessionState.idle,
        ),
      );

      await _ttsService.speakFinal('حصل خطأ في تحميل الموديل.');
    }
  }

  void attachSession(CameraSessionController? session) {
    if (_disposed) return;

    _session = session;
  }

  Future<void> onDoubleTap() async {
    if (!_uiState.canStartCamera || !_inferenceService.isReady) return;

    if (_uiState.sessionState != CurrencySessionState.idle) {
      return;
    }

    await _startNewDetectionSession();
  }

  Future<void> startDetection() async {
    await onDoubleTap();
  }

  Future<void> _startNewDetectionSession() async {
    if (_disposed) return;

    await _ttsService.stop();

    _scanGeneration++;

    _resetStability();
    _resetQuickRecognition();
    _resetVerification();

    _lastStableLabel = '';
    _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

    _setUiState(
      _uiState.copyWith(
        status: 'جاري التحليل',
        label: '…',
        guide: 'وجّه الكاميرا ناحية العملة',
        confidence: 0.0,
        sessionState: CurrencySessionState.guiding,
      ),
    );

    unawaited(
      _ttsService.speakGuide('وجّه الكاميرا ناحية العملة.', isFallback: false),
    );
  }

  Future<void> onFrame(InputFrame frame) async {
    if (_disposed) return;
    if (!_uiState.canStartCamera || !_inferenceService.isReady) return;
    if (_ttsService.isFinalSpeechActive) return;

    final currentState = _uiState.sessionState;

    if (!(currentState == CurrencySessionState.guiding ||
        currentState == CurrencySessionState.locking ||
        currentState == CurrencySessionState.capturing)) {
      return;
    }

    final frameGeneration = _scanGeneration;
    final now = DateTime.now();

    if (now.difference(_lastRun).inMilliseconds <
        CurrencyConstants.frameIntervalMs) {
      return;
    }

    if (_processing) return;

    _processing = true;
    _lastRun = now;

    try {
      await _autoFlashService.updateFromFrame(frame: frame, session: _session);

      final result = await _inferenceService.detectFromFrame(frame);

      if (_disposed) return;
      if (frameGeneration != _scanGeneration) return;
      if (_ttsService.isFinalSpeechActive) return;

      final stateAfterDetection = _uiState.sessionState;

      if (stateAfterDetection == CurrencySessionState.capturing) {
        await _handleVerificationFrame(result);
        return;
      }

      if (!(stateAfterDetection == CurrencySessionState.guiding ||
          stateAfterDetection == CurrencySessionState.locking)) {
        return;
      }

      if (result == null) {
        _resetStability();
        _resetQuickRecognition();

        const fallback = 'حرك العملة أمام الكاميرا';

        _setUiState(
          _uiState.copyWith(
            status: 'جاري البحث',
            label: '…',
            guide: fallback,
            confidence: 0.0,
            sessionState: CurrencySessionState.guiding,
          ),
        );

        unawaited(_ttsService.speakGuide(fallback, isFallback: true));

        return;
      }

      final quickAnnounced = await _tryQuickAnnounce(
        label: result.label,
        confidence: result.confidence,
      );

      if (quickAnnounced) return;

      final guide = _guidanceService.compute(
        box: result.boundingBox,
        confidence: result.confidence,
        inputSize: _inferenceService.inputSize,
      );

      if (guide.isNotEmpty) {
        _resetStability();

        _setUiState(
          _uiState.copyWith(
            status: 'جاري التوجيه',
            label: result.label,
            guide: guide,
            confidence: result.confidence,
            sessionState: CurrencySessionState.guiding,
          ),
        );

        unawaited(_ttsService.speakGuide(guide, isFallback: false));

        return;
      }

      _setUiState(
        _uiState.copyWith(
          status: 'العملة في الإطار',
          label: result.label,
          guide: 'حافِظ على نفس الوَضْع… لحظة',
          confidence: result.confidence,
          sessionState: CurrencySessionState.locking,
        ),
      );

      final locked = _stabilityTracker.update(
        box: result.boundingBox,
        label: result.label,
        confidence: result.confidence,
      );

      if (!locked) {
        unawaited(
          _ttsService.speakGuide('حافِظ على نفس الوَضْع', isFallback: false),
        );
        return;
      }

      _lastStableLabel = result.label;

      _vibrateStrong();

      _startStreamVerification();
    } catch (_) {
      if (_disposed) return;

      _setUiState(
        _uiState.copyWith(
          status: 'خطأ أثناء التحليل',
          guide: 'حصل خطأ أثناء قراءة العملة',
          sessionState: CurrencySessionState.guiding,
        ),
      );
    } finally {
      _processing = false;
    }
  }

  Future<bool> _tryQuickAnnounce({
    required String label,
    required double confidence,
  }) async {
    final quickResult = _quickRecognitionTracker.update(
      label: label,
      confidence: confidence,
    );

    if (!quickResult.shouldAnnounce) {
      return false;
    }

    if (_uiState.sessionState != CurrencySessionState.guiding &&
        _uiState.sessionState != CurrencySessionState.locking) {
      return false;
    }

    final winner = quickResult.label;
    final winnerConfidence = quickResult.confidence;
    final generation = _scanGeneration;

    _resetStability();
    _resetQuickRecognition();
    _resetVerification();

    await _autoFlashService.turnOff(_session);

    _setUiState(
      _uiState.copyWith(
        status: 'تم التعرف',
        label: winner,
        guide: 'تم التعرف مباشرة',
        confidence: winnerConfidence,
        sessionState: CurrencySessionState.capturing,
      ),
    );

    _vibrateStrong();

    await _speakFinalMessagesThenReturnIdle(
      generation: generation,
      messages: [
        'العملة هي $winner',
        'لكشف عملة أخرى اضغط مرتين أو قل تصوير. وللإغلاق قل إغلاق.',
      ],
    );

    return true;
  }

  void _startStreamVerification() {
    if (_uiState.sessionState == CurrencySessionState.capturing) return;

    _verificationResults.clear();
    _finishingVerification = false;
    _lastVerificationAcceptedAt = DateTime.fromMillisecondsSinceEpoch(0);

    _setUiState(
      _uiState.copyWith(
        status: 'جاري التأكيد',
        label: _lastStableLabel.isNotEmpty ? _lastStableLabel : '…',
        guide: 'انتظر لحظة… جاري التأكيد',
        sessionState: CurrencySessionState.capturing,
      ),
    );

    _ttsService.speakDuringCapture('انتظر لحظة.');
  }

  Future<void> _handleVerificationFrame(CurrencyDetectionResult? result) async {
    if (_finishingVerification) return;

    final now = DateTime.now();

    if (now.difference(_lastVerificationAcceptedAt).inMilliseconds <
        CurrencyConstants.betweenShotsDelayMs) {
      return;
    }

    _lastVerificationAcceptedAt = now;

    String label;

    if (result != null) {
      label = result.label;
    } else if (_lastStableLabel.isNotEmpty) {
      label = _lastStableLabel;
    } else {
      label = 'مش واضح';
    }

    _verificationResults.add(label);

    final currentCount = _verificationResults.length;
    final total = CurrencyConstants.shotsCount;

    _setUiState(
      _uiState.copyWith(
        status: 'جاري التأكيد',
        label: label,
        guide: 'تأكيد $currentCount من $total',
        confidence: result?.confidence ?? _uiState.confidence,
        sessionState: CurrencySessionState.capturing,
      ),
    );

    if (_verificationResults.length < CurrencyConstants.shotsCount) {
      return;
    }

    _finishingVerification = true;

    await _finishStreamVerification();
  }

  Future<void> _finishStreamVerification() async {
    final generation = _scanGeneration;
    final finalLabel = _bestConfirmedLabel(_verificationResults);

    if (finalLabel == null) {
      await _speakFinalMessagesThenReturnIdle(
        generation: generation,
        messages: [
          'النتيجة غير مؤكدة. حاول تاني.',
          'لكشف عملة أخرى اضغط مرتين أو قل تصوير. وللإغلاق قل إغلاق.',
        ],
      );

      return;
    }

    _setUiState(
      _uiState.copyWith(
        status: 'تم التعرف',
        label: finalLabel,
        guide: 'تم تحديد العملة بنجاح',
        sessionState: CurrencySessionState.capturing,
      ),
    );

    await _speakFinalMessagesThenReturnIdle(
      generation: generation,
      messages: [
        'العملة هي $finalLabel',
        'لكشف عملة أخرى اضغط مرتين أو قل تصوير. وللإغلاق قل إغلاق.',
      ],
    );
  }

  Future<void> _speakFinalMessagesThenReturnIdle({
    required int generation,
    required List<String> messages,
  }) async {
    var resumedVoiceEarly = false;

    try {
      await _pauseVoiceForFinalSpeech?.call();
    } catch (_) {}

    try {
      if (_disposed || generation != _scanGeneration) return;

      if (messages.isEmpty) {
        await _returnToIdleUi();

        if (_disposed || generation != _scanGeneration) return;

        try {
          await _resumeVoiceAfterFinalSpeech?.call();
          resumedVoiceEarly = true;
        } catch (_) {}

        return;
      }

      final firstMessage = messages.first.trim();

      if (firstMessage.isNotEmpty) {
        await _ttsService.speakFinal(firstMessage);
      }

      if (_disposed || generation != _scanGeneration) return;

      await _returnToIdleUi();

      if (_disposed || generation != _scanGeneration) return;

      try {
        await _resumeVoiceAfterFinalSpeech?.call();
        resumedVoiceEarly = true;
      } catch (_) {}

      for (final message in messages.skip(1)) {
        if (_disposed || generation != _scanGeneration) return;

        final cleanMessage = message.trim();

        if (cleanMessage.isEmpty) continue;

        await _ttsService.speakFinal(cleanMessage);
      }
    } finally {
      if (!_disposed && generation == _scanGeneration && !resumedVoiceEarly) {
        try {
          await _resumeVoiceAfterFinalSpeech?.call();
        } catch (_) {}
      }
    }
  }

  String? _bestConfirmedLabel(List<String> labelsList) {
    final validLabels = labelsList
        .map((item) => item.trim())
        .where(
          (item) => item.isNotEmpty && item != 'مش واضح' && item != 'غير معروف',
        )
        .toList();

    if (validLabels.isEmpty) return null;

    final counts = <String, int>{};

    for (final label in validLabels) {
      counts[label] = (counts[label] ?? 0) + 1;
    }

    String? best;
    int bestCount = 0;

    counts.forEach((key, value) {
      if (value > bestCount) {
        best = key;
        bestCount = value;
      }
    });

    if (best != null && bestCount >= 2) {
      return best;
    }

    if (validLabels.length == 1 &&
        _lastStableLabel.isNotEmpty &&
        validLabels.first == _lastStableLabel) {
      return validLabels.first;
    }

    return null;
  }

  Future<void> _returnToIdleUi() async {
    await _autoFlashService.turnOff(_session);

    _resetStability();
    _resetQuickRecognition();
    _resetVerification();

    _lastStableLabel = '';
    _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

    _setUiState(
      _uiState.copyWith(
        status: 'جاهز',
        label: '—',
        guide: 'لكشف عملة أخرى اضغط مرتين أو قل تصوير',
        confidence: 0.0,
        sessionState: CurrencySessionState.idle,
      ),
    );
  }

  void _resetQuickRecognition() {
    _quickRecognitionTracker.reset();
  }

  void _resetStability() {
    _stabilityTracker.reset();
  }

  void _resetVerification() {
    _verificationResults.clear();
    _finishingVerification = false;
    _lastVerificationAcceptedAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _vibrateStrong() {
    try {
      HapticFeedback.heavyImpact();
      HapticFeedback.mediumImpact();
      HapticFeedback.vibrate();
    } catch (_) {}
  }

  void _setUiState(CurrencyUiState newState) {
    if (_disposed) return;

    _uiState = newState;
    notifyListeners();
  }

  Future<void> disposeController() async {
    if (_disposed) return;

    _disposed = true;
    _processing = false;
    _scanGeneration++;

    try {
      await _autoFlashService.turnOff(_session);
    } catch (_) {}

    try {
      await _ttsService.stop();
    } catch (_) {}

    try {
      _inferenceService.dispose();
    } catch (_) {}

    try {
      _ttsService.dispose();
    } catch (_) {}

    _session = null;
  }
}
