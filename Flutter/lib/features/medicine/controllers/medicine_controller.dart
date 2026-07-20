import 'package:flutter/foundation.dart';

import '../../../core/camera/camera_session.dart';
import '../../../core/camera/input_frame.dart';
import '../../../core/files/temp_capture_cleanup.dart';
import '../../../core/network/network_check_service.dart';
import '../../../core/permissions/permission_service.dart';
import '../models/medicine_ui_state.dart';
import '../services/medicine_api_service.dart';
import '../services/medicine_auto_flash_service.dart';
import '../services/medicine_tts_service.dart';

class MedicineController extends ChangeNotifier {
  final MedicineApiService _apiService;
  final MedicineTtsService _ttsService;
  final MedicineAutoFlashService _autoFlashService;

  MedicineUiState _uiState = MedicineUiState.initial();
  MedicineUiState get uiState => _uiState;

  CameraSessionController? _session;

  bool _disposed = false;
  bool _busy = false;
  int _operationId = 0;

  MedicineController({
    MedicineApiService? apiService,
    MedicineTtsService? ttsService,
    MedicineAutoFlashService? autoFlashService,
  }) : _apiService = apiService ?? MedicineApiService(),
       _ttsService = ttsService ?? MedicineTtsService(),
       _autoFlashService = autoFlashService ?? MedicineAutoFlashService();

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

      await _ttsService.speak('لازم إذن الكاميرا عشان نقدر نحدد الدواء.');
      return;
    }

    _emit(
      _uiState.copyWith(
        statusText: 'جاهز لتحديد الدواء',
        titleText: 'بانتظار تحديد الدواء',
        subtitleText: 'وجّه علبة الدواء داخل الإطار ثم اضغط مرتين أو قل تصوير',
        isCameraAllowed: true,
        isBusy: false,
        hasResult: false,
        clearResult: true,
      ),
    );

    await _ttsService.speak(
      'تم فتح قارئ الأدوية. للتشغيل اضغط مرتين أو قل تصوير. للإغلاق قل إغلاق او اضغط سهم الخروج أعلا الشاشه يسارا.',
    );
  }

  void attachSession(CameraSessionController session) {
    if (_disposed) return;
    _session = session;
  }

  Future<void> onFrame(InputFrame frame) async {
    if (_disposed) return;

    await _autoFlashService.updateFromFrame(frame: frame, session: _session);

    if (_disposed) return;

    _syncTorchState();
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
        titleText: 'جاري تحليل الدواء',
        subtitleText: 'ثبت العلبة أمام الكاميرا لحظات من فضلك',
        isBusy: true,
        hasResult: false,
        clearResult: true,
      ),
    );

    await _speakWithVoicePaused(
      'تمام. جاري تصوير الدواء وتحليله.',
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

      final results = await _apiService.detectDrugFromImageFile(
        capturedImagePath,
      );

      if (!_isCurrentOperation(operation)) return;

      if (results.isEmpty) {
        _emit(
          _uiState.copyWith(
            statusText: 'لم يتم التعرف',
            titleText: 'تعذر تحديد الدواء',
            subtitleText: 'قرّب العلبة وثبت الإضاءة ثم جرّب مرة تانية',
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
          'مش قادر أحدد الدواء. قرّب العلبة وثبت الإضاءة وحاول مرة أخرى. للتحديد مرة أخرى اضغط مرتين أو قل تصوير. وللإغلاق قل إغلاق.',
          operation: operation,
          pauseVoiceForSpeech: pauseVoiceForSpeech,
          resumeVoiceForAnalysis: null,
        );
      } else {
        final result = results.first;
        final speechText = result.buildSpeechText();

        _emit(
          _uiState.copyWith(
            statusText: 'تم التعرف بنجاح',
            titleText: result.displayName,
            subtitleText: result.shortDescription,
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
          '$speechText. للتحديد مرة أخرى اضغط مرتين أو قل تصوير. وللإغلاق قل إغلاق.',
          operation: operation,
          pauseVoiceForSpeech: pauseVoiceForSpeech,
          resumeVoiceForAnalysis: null,
        );
      }
    } on MedicineApiException catch (e) {
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
        '${e.message}. للتحديد مرة أخرى اضغط مرتين أو قل تصوير. وللإغلاق قل إغلاق.',
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
        '${NetworkCheckService.serverProblemMessage}. للتحديد مرة أخرى اضغط مرتين أو قل تصوير. وللإغلاق قل إغلاق.',
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

        _syncTorchState();
      }
    }
  }

  Future<void> speakCurrentDetails() async {
    if (_disposed) return;

    final result = _uiState.result;

    if (result == null) {
      await _ttsService.speak('لا توجد تفاصيل متاحة الآن.');
      return;
    }

    await _ttsService.speak(result.buildSpeechText());
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

    _syncTorchState();

    try {
      await onReadyForNextCapture?.call();
    } catch (_) {}
  }

  bool _isCurrentOperation(int operation) {
    return !_disposed && operation == _operationId;
  }

  void _syncTorchState() {
    final currentTorch = _autoFlashService.isTorchOn;

    if (_uiState.isTorchOn != currentTorch) {
      _emit(_uiState.copyWith(isTorchOn: currentTorch));
    }
  }

  void _emit(MedicineUiState newState) {
    _uiState = newState;

    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> disposeController() async {
    if (_disposed) return;

    _disposed = true;
    _busy = false;
    _operationId++;

    final session = _session;
    _session = null;

    await _safeStopStream(session);
    await _safeTurnOffFlash(session);
    await _safeDisposeTts();
  }

  Future<void> _safeStopStream(CameraSessionController? session) async {
    if (session == null) return;

    try {
      await session.stopStream().timeout(const Duration(milliseconds: 900));
    } catch (_) {}
  }

  Future<void> _safeTurnOffFlash(CameraSessionController? session) async {
    try {
      await _autoFlashService
          .turnOff(session)
          .timeout(const Duration(milliseconds: 1200));
    } catch (_) {
      _autoFlashService.setKnownTorchState(false);
    }
  }

  Future<void> _safeDisposeTts() async {
    try {
      await _ttsService.dispose().timeout(const Duration(milliseconds: 800));
    } catch (_) {}
  }
}
