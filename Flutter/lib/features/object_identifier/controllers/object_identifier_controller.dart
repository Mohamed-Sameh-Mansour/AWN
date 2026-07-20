import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/camera/camera_session.dart';
import '../../../core/camera/input_frame.dart';
import '../../../core/files/temp_capture_cleanup.dart';
import '../../../core/network/network_check_service.dart';
import '../../../core/permissions/permission_service.dart';
import '../models/object_identifier_ui_state.dart';
import '../services/object_identifier_api_service.dart';
import '../services/object_identifier_auto_flash_service.dart';
import '../services/object_identifier_tts_service.dart';

class ObjectIdentifierController extends ChangeNotifier {
  final ObjectIdentifierApiService _apiService;
  final ObjectIdentifierTtsService _ttsService;
  final ObjectIdentifierAutoFlashService _autoFlashService;

  ObjectIdentifierUiState _uiState = ObjectIdentifierUiState.initial();

  ObjectIdentifierUiState get uiState => _uiState;

  CameraSessionController? _session;

  bool _disposed = false;
  bool _busy = false;
  int _operationId = 0;

  ObjectIdentifierController({
    ObjectIdentifierApiService? apiService,
    ObjectIdentifierTtsService? ttsService,
    ObjectIdentifierAutoFlashService? autoFlashService,
  }) : _apiService = apiService ?? ObjectIdentifierApiService(),
       _ttsService = ttsService ?? ObjectIdentifierTtsService(),
       _autoFlashService =
           autoFlashService ?? ObjectIdentifierAutoFlashService();

  Future<void> init() async {
    await _ttsService.init();

    if (_disposed) return;

    final hasCameraPermission = await PermissionService.ensureCameraPermission(
      speak: _ttsService.speak,
    );

    if (_disposed) return;

    if (!hasCameraPermission) {
      _emit(
        _uiState.copyWith(
          statusText: 'لازم إذن الكاميرا',
          titleText: 'الكاميرا غير متاحة',
          subtitleText: 'فعّل إذن الكاميرا من إعدادات الجهاز ثم ارجع للتجربة',
          isCameraAllowed: false,
          isBusy: false,
          hasResult: false,
          clearResult: true,
        ),
      );

      await _ttsService.speak(
        'لازم إذن الكاميرا عشان نقدر نستخدم معرفة الأشياء.',
      );
      return;
    }

    _emit(
      _uiState.copyWith(
        statusText: 'جاهز',
        titleText: 'معرفة الأشياء',
        subtitleText: 'وجّه الكاميرا نحو الشيء ثم اضغط مرتين أو قل تصوير',
        isCameraAllowed: true,
        isBusy: false,
        hasResult: false,
        clearResult: true,
      ),
    );

    await _ttsService.speak(
      'تم فتح كاشف الأشياء. للتشغيل اضغط مرتين أو قل تصوير. للإغلاق قل إغلاق أو اضغط سهم الخروج أعلا الشاشه يسارا.',
    );
  }

  void attachSession(CameraSessionController session) {
    if (_disposed) return;
    _session = session;
  }

  Future<void> onFrame(InputFrame frame) async {
    if (_disposed) return;

    await _autoFlashService.updateFromFrame(frame: frame, session: _session);
  }

  Future<void> captureAndAnalyze({
    Future<void> Function()? pauseVoiceForSpeech,
    Future<void> Function()? resumeVoiceForAnalysis,
    Future<void> Function()? onReadyForNextCapture,
  }) async {
    if (_disposed) return;
    if (_busy) return;

    if (!_uiState.isCaptureEnabled) {
      await _speakWithVoicePaused(
        'الكاميرا غير جاهزة الآن.',
        pauseVoiceForSpeech: pauseVoiceForSpeech,
        resumeVoiceForAnalysis: resumeVoiceForAnalysis,
      );
      return;
    }

    if (_session == null) {
      await _speakWithVoicePaused(
        'الكاميرا غير جاهزة الآن.',
        pauseVoiceForSpeech: pauseVoiceForSpeech,
        resumeVoiceForAnalysis: resumeVoiceForAnalysis,
      );
      return;
    }

    final operation = ++_operationId;

    _busy = true;

    await _ttsService.stop();

    _emit(
      _uiState.copyWith(
        statusText: 'جاري التصوير والتحليل',
        titleText: 'جاري تحليل الصورة',
        subtitleText: 'ثبت الكاميرا لحظات من فضلك',
        isBusy: true,
        hasResult: false,
        clearResult: true,
      ),
    );

    await _speakWithVoicePaused(
      'تمام. جاري تحليل الصورة.',
      operation: operation,
      pauseVoiceForSpeech: pauseVoiceForSpeech,
      resumeVoiceForAnalysis: resumeVoiceForAnalysis,
    );

    String? capturedImagePath;

    try {
      if (!_isCurrentOperation(operation)) return;

      await _session!.stopStream();

      if (!_isCurrentOperation(operation)) return;

      final shot = await _session!.takePicture(resumeStream: false);

      if (!_isCurrentOperation(operation)) return;

      if (shot == null) {
        throw Exception('capture_failed');
      }

      capturedImagePath = shot.path;

      final result = await _apiService.analyzeImageFile(capturedImagePath);

      if (!_isCurrentOperation(operation)) return;

      if (result == null || !result.hasUsefulText) {
        _emit(
          _uiState.copyWith(
            statusText: 'لم يتم التعرف',
            titleText: 'تعذر تحليل الصورة',
            subtitleText: 'قرّب الشيء وثبت الإضاءة ثم جرّب مرة تانية',
            isBusy: false,
            hasResult: false,
            clearResult: true,
          ),
        );

        await _markReadyForNextCapture(
          operation,
          onReadyForNextCapture: onReadyForNextCapture,
        );

        await _speakWithVoicePaused(
          'مش قادر أتعرف على الشيء. قرّب الكاميرا وثبت الإضاءة وحاول مرة أخرى. للكشف مرة أخرى اضغط مرتين أو قل تصوير. وللإغلاق قل إغلاق.',
          operation: operation,
          pauseVoiceForSpeech: pauseVoiceForSpeech,
          resumeVoiceForAnalysis: null,
        );
      } else {
        _emit(
          _uiState.copyWith(
            statusText: 'تم التحليل بنجاح',
            titleText: result.displayTitle,
            subtitleText: result.displayDescription,
            isBusy: false,
            hasResult: true,
            result: result,
          ),
        );

        await _markReadyForNextCapture(
          operation,
          onReadyForNextCapture: onReadyForNextCapture,
        );

        await _speakWithVoicePaused(
          '${result.speechText}. للكشف مرة أخرى اضغط مرتين أو قل تصوير. وللإغلاق قل إغلاق.',
          operation: operation,
          pauseVoiceForSpeech: pauseVoiceForSpeech,
          resumeVoiceForAnalysis: null,
        );
      }
    } on ObjectIdentifierApiException catch (e) {
      if (!_isCurrentOperation(operation)) return;

      final title = e.isNoInternet ? 'مفيش إنترنت' : 'مشكلة في السيرفر';

      _emit(
        _uiState.copyWith(
          statusText: title,
          titleText: title,
          subtitleText: e.message,
          isBusy: false,
          hasResult: false,
          clearResult: true,
        ),
      );

      await _markReadyForNextCapture(
        operation,
        onReadyForNextCapture: onReadyForNextCapture,
      );

      await _speakWithVoicePaused(
        '${e.message}. للكشف مرة أخرى اضغط مرتين أو قل تصوير. وللإغلاق قل إغلاق.',
        operation: operation,
        pauseVoiceForSpeech: pauseVoiceForSpeech,
        resumeVoiceForAnalysis: null,
      );
    } catch (_) {
      if (!_isCurrentOperation(operation)) return;

      _emit(
        _uiState.copyWith(
          statusText: 'مشكلة في السيرفر',
          titleText: 'مشكلة في السيرفر',
          subtitleText: NetworkCheckService.serverProblemMessage,
          isBusy: false,
          hasResult: false,
          clearResult: true,
        ),
      );

      await _markReadyForNextCapture(
        operation,
        onReadyForNextCapture: onReadyForNextCapture,
      );

      await _speakWithVoicePaused(
        '${NetworkCheckService.serverProblemMessage}. للكشف مرة أخرى اضغط مرتين أو قل تصوير. وللإغلاق قل إغلاق.',
        operation: operation,
        pauseVoiceForSpeech: pauseVoiceForSpeech,
        resumeVoiceForAnalysis: null,
      );
    } finally {
      await TempCaptureCleanup.deleteCapturedImage(capturedImagePath);

      if (_isCurrentOperation(operation)) {
        _busy = false;

        try {
          await _session?.startStream();
        } catch (_) {}
      }
    }
  }

  Future<void> speakCurrentResult() async {
    final result = _uiState.result;

    if (result == null) {
      await _ttsService.speak('لا توجد نتيجة متاحة الآن.');
      return;
    }

    await _ttsService.speak(result.speechText);
  }

  Future<void> _speakWithVoicePaused(
    String text, {
    int? operation,
    Future<void> Function()? pauseVoiceForSpeech,
    Future<void> Function()? resumeVoiceForAnalysis,
  }) async {
    if (_disposed) return;
    if (operation != null && !_isCurrentOperation(operation)) return;

    try {
      await pauseVoiceForSpeech?.call();
    } catch (_) {}

    if (_disposed) return;
    if (operation != null && !_isCurrentOperation(operation)) return;

    await _ttsService.speak(text);

    if (_disposed) return;
    if (operation != null && !_isCurrentOperation(operation)) return;

    try {
      await resumeVoiceForAnalysis?.call();
    } catch (_) {}
  }

  Future<void> _markReadyForNextCapture(
    int operation, {
    Future<void> Function()? onReadyForNextCapture,
  }) async {
    if (!_isCurrentOperation(operation)) return;

    _busy = false;

    try {
      await _session?.startStream();
    } catch (_) {}

    try {
      await onReadyForNextCapture?.call();
    } catch (_) {}
  }

  bool _isCurrentOperation(int operation) {
    return !_disposed && operation == _operationId;
  }

  void _emit(ObjectIdentifierUiState newState) {
    _uiState = newState;

    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> disposeController() async {
    if (_disposed) return;

    _disposed = true;
    _operationId++;

    await _autoFlashService.turnOff(_session);
    await _ttsService.dispose();
  }
}
