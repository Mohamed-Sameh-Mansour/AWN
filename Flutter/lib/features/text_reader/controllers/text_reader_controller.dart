import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../../../core/files/temp_capture_cleanup.dart';

import '../../../core/camera/camera_session.dart';
import '../../../core/camera/input_frame.dart';
import '../../../core/network/network_check_service.dart';
import '../../../core/permissions/permission_service.dart';
import '../models/text_reader_ui_state.dart';
import '../services/ocr_service.dart';
import '../services/text_reader_api_service.dart';
import '../services/text_reader_auto_flash_service.dart';
import '../services/text_reader_tts_service.dart';

class TextReaderController extends ChangeNotifier {
  final OcrService _englishOcrService;
  final TextReaderApiService _serverOcrService;
  final TextReaderTtsService _ttsService;
  final TextReaderAutoFlashService _autoFlashService;

  TextReaderUiState _uiState = TextReaderUiState.initial();

  TextReaderUiState get uiState => _uiState;

  CameraSessionController? _session;

  bool _busy = false;
  bool _disposed = false;
  bool _lastKnownHasInternet = true;

  int _operationId = 0;

  DateTime _lastActionTime = DateTime.fromMillisecondsSinceEpoch(0);

  TextReaderController({
    OcrService? englishOcrService,
    TextReaderApiService? serverOcrService,
    TextReaderTtsService? ttsService,
    TextReaderAutoFlashService? autoFlashService,
  }) : _englishOcrService = englishOcrService ?? OcrService(),
       _serverOcrService = serverOcrService ?? TextReaderApiService(),
       _ttsService = ttsService ?? TextReaderTtsService(),
       _autoFlashService = autoFlashService ?? TextReaderAutoFlashService();

  Future<void> init() async {
    await _ttsService.init();

    if (_disposed) return;

    final hasCameraPermission = await PermissionService.ensureCameraPermission(
      speak: _ttsService.speakInstruction,
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
          clearRecognizedText: true,
        ),
      );

      await _ttsService.speakInstruction(
        'لازم إذن الكاميرا عشان نقدر نقرأ النصوص.',
      );
      return;
    }

    _lastKnownHasInternet = await _checkInternetFast();

    if (_disposed) return;

    if (_lastKnownHasInternet) {
      _emit(
        _uiState.copyWith(
          mode: TextReaderMode.arabic,
          statusText: 'جاهز',
          titleText: 'قارئ النصوص',
          subtitleText: 'لقراءة النص اضغط مرتين أو قل تصوير. للإغلاق قل إغلاق.',
          isCameraAllowed: true,
          isBusy: false,
          hasResult: false,
          clearRecognizedText: true,
          isTorchOn: false,
        ),
      );

      await _ttsService.speakInstruction(
        'لقراءة النص اضغط مرتين أو قل تصوير. للإغلاق قل إغلاق أو اضغط سهم الخروج أعلا الصفحه يسارا.',
      );
    } else {
      _emit(
        _uiState.copyWith(
          mode: TextReaderMode.english,
          statusText: 'غير متصل بالإنترنت',
          titleText: 'قارئ النصوص أوفلاين',
          subtitleText:
              'سيتم قراءة النص الإنجليزي فقط. للقراءة اضغط مرتين أو قل تصوير. للإغلاق قل إغلاق.',
          isCameraAllowed: true,
          isBusy: false,
          hasResult: false,
          clearRecognizedText: true,
          isTorchOn: false,
        ),
      );

      await _ttsService.speakInstruction(
        'أنت غير متصل بالإنترنت. سيتم قراءة النص الإنجليزي فقط. للقراءة اضغط مرتين أو قل تصوير. للإغلاق قل إغلاق.',
      );
    }
  }

  void attachSession(CameraSessionController session) {
    if (_disposed) return;

    _session = session;
  }

  Future<void> onFrame(InputFrame frame) async {
    if (_disposed) return;
    if (!_uiState.isCameraAllowed) return;

    await _autoFlashService.updateFromFrame(frame: frame, session: _session);

    if (_uiState.isTorchOn != _autoFlashService.isTorchOn) {
      _emit(_uiState.copyWith(isTorchOn: _autoFlashService.isTorchOn));
    }
  }

  Future<void> cancelCurrentOperation() async {
    if (_disposed) return;

    _operationId++;
    _busy = false;

    await _stopAllSpeech();

    if (_disposed) return;

    _emit(
      _uiState.copyWith(
        statusText: 'جاهز',
        titleText: 'قارئ النصوص',
        subtitleText: 'قل تصوير للقراءة من جديد. قل إغلاق للخروج.',
        isBusy: false,
      ),
    );

    try {
      await _session?.startStream();
    } catch (_) {}
  }

  Future<void> readText() async {
    final operation = _beginAction();

    if (operation == null) return;

    final hasInternet = await _checkInternetForOperation(operation);

    if (!_isCurrent(operation)) return;

    final shot = await _captureImage(
      operation: operation,
      mode: hasInternet ? TextReaderMode.arabic : TextReaderMode.english,
      statusText: hasInternet
          ? 'جاري إرسال الصورة للسيرفر'
          : 'جاري القراءة أوفلاين',
      titleText: hasInternet ? 'قراءة النص' : 'قراءة إنجليزي أوفلاين',
      subtitleText: hasInternet
          ? 'ثبّت الكاميرا لحظات'
          : 'أنت غير متصل بالإنترنت. سيتم قراءة النص الإنجليزي فقط.',
      speakText: hasInternet
          ? 'تمام. جاري قراءة النص.'
          : 'أنت غير متصل بالإنترنت. سيتم قراءة النص الإنجليزي فقط.',
    );

    if (shot == null) {
      await _finishAction(operation);
      return;
    }

    final capturedImagePath = shot.path;

    try {
      if (!_isCurrent(operation)) return;

      if (hasInternet) {
        await _readServerTextFromShot(
          operation: operation,
          imagePath: capturedImagePath,
        );
      } else {
        await _readOfflineEnglishFromShot(
          operation: operation,
          imagePath: capturedImagePath,
        );
      }
    } on TextReaderApiException catch (e) {
      if (!_isCurrent(operation)) return;

      if (e.isNoInternet) {
        await _handleServerLostInternet(
          operation: operation,
          imagePath: capturedImagePath,
          message: e.message,
        );
      } else {
        await _handleServerError(operation: operation, message: e.message);
      }
    } catch (_) {
      if (!_isCurrent(operation)) return;

      await _handleServerError(
        operation: operation,
        message: NetworkCheckService.serverProblemMessage,
      );
    } finally {
      await TempCaptureCleanup.deleteCapturedImage(capturedImagePath);
      await _finishAction(operation);
    }
  }

  Future<void> _readServerTextFromShot({
    required int operation,
    required String imagePath,
  }) async {
    final result = await _serverOcrService.extractArabicFromImageFile(
      imagePath,
    );

    if (!_isCurrent(operation)) return;

    final text = result.text.trim();

    if (text.isEmpty) {
      _busy = false;

      _emit(
        _uiState.copyWith(
          mode: TextReaderMode.arabic,
          statusText: 'لم يتم العثور على نص',
          titleText: 'النص المقروء',
          subtitleText: 'قرّب النص وثبت الإضاءة ثم جرّب مرة تانية',
          isBusy: false,
          hasResult: false,
          clearRecognizedText: true,
        ),
      );

      await _speakInstruction(
        operation: operation,
        text:
            'مش قادر أقرأ نص واضح. قرّب النص وثبت الإضاءة وحاول مرة أخرى. للقراءة مرة أخرى قل تصوير.',
      );

      return;
    }

    _busy = false;

    _emit(
      _uiState.copyWith(
        mode: TextReaderMode.arabic,
        statusText: 'تمت القراءة',
        titleText: 'النص المقروء',
        subtitleText: 'يتم الآن قراءة النص بصوت مناسب للعربي والإنجليزي',
        recognizedText: text,
        isBusy: false,
        hasResult: true,
      ),
    );

    await _speakResult(operation: operation, text: text);
  }

  Future<void> _readOfflineEnglishFromShot({
    required int operation,
    required String imagePath,
  }) async {
    try {
      final text = await _englishOcrService.extractEnglishFromImageFile(
        imagePath,
      );

      if (!_isCurrent(operation)) return;

      _busy = false;

      _emit(
        _uiState.copyWith(
          mode: TextReaderMode.english,
          statusText: 'تمت القراءة أوفلاين',
          titleText: 'English Offline Text',
          subtitleText: 'تم استخدام قراءة الإنجليزي بدون إنترنت',
          recognizedText: text,
          isBusy: false,
          hasResult: true,
        ),
      );

      await _speakResult(operation: operation, text: text);
    } on OcrException catch (e) {
      if (!_isCurrent(operation)) return;

      _busy = false;

      _emit(
        _uiState.copyWith(
          mode: TextReaderMode.english,
          statusText: 'تعذر القراءة أوفلاين',
          titleText: 'English Offline Failed',
          subtitleText: e.message,
          isBusy: false,
          hasResult: false,
          clearRecognizedText: true,
        ),
      );

      await _speakInstruction(
        operation: operation,
        text:
            'أنت غير متصل بالإنترنت، والقراءة الأوفلاين بتدعم الإنجليزي فقط. مش قادر أقرأ نص إنجليزي واضح. قرّب الكاميرا وحاول تاني. للقراءة مرة أخرى قل تصوير.',
      );
    } catch (e) {
      if (!_isCurrent(operation)) return;

      _busy = false;

      _emit(
        _uiState.copyWith(
          mode: TextReaderMode.english,
          statusText: 'خطأ في القراءة أوفلاين',
          titleText: 'Offline OCR Error',
          subtitleText: e.toString(),
          isBusy: false,
          hasResult: false,
          clearRecognizedText: true,
        ),
      );

      await _speakInstruction(
        operation: operation,
        text: 'حصل خطأ أثناء القراءة الأوفلاين. للقراءة مرة أخرى قل تصوير.',
      );
    }
  }

  Future<void> _handleServerLostInternet({
    required int operation,
    required String imagePath,
    required String message,
  }) async {
    if (!_isCurrent(operation)) return;

    _emit(
      _uiState.copyWith(
        mode: TextReaderMode.english,
        statusText: 'غير متصل بالإنترنت',
        titleText: 'تحويل للأوفلاين',
        subtitleText: 'سيتم تشغيل قراءة الإنجليزي أوفلاين على نفس الصورة',
        isBusy: true,
        hasResult: false,
        clearRecognizedText: true,
      ),
    );

    await _speakInstruction(
      operation: operation,
      text: 'أنت غير متصل بالإنترنت. سيتم قراءة النص الإنجليزي فقط.',
    );

    if (!_isCurrent(operation)) return;

    await _readOfflineEnglishFromShot(
      operation: operation,
      imagePath: imagePath,
    );
  }

  Future<void> _handleServerError({
    required int operation,
    required String message,
  }) async {
    if (!_isCurrent(operation)) return;

    _busy = false;

    _emit(
      _uiState.copyWith(
        mode: TextReaderMode.arabic,
        statusText: 'مشكلة في السيرفر',
        titleText: 'مشكلة في السيرفر',
        subtitleText: message,
        isBusy: false,
        hasResult: false,
        clearRecognizedText: true,
      ),
    );

    await _speakInstruction(
      operation: operation,
      text: '$message للقراءة مرة أخرى قل تصوير.',
    );
  }

  Future<XFile?> _captureImage({
    required int operation,
    required TextReaderMode mode,
    required String statusText,
    required String titleText,
    required String subtitleText,
    required String speakText,
  }) async {
    if (!_isCurrent(operation)) return null;

    if (_session == null) {
      await _speakInstruction(
        operation: operation,
        text: 'الكاميرا غير جاهزة الآن.',
      );

      return null;
    }

    await _stopAllSpeech();

    if (!_isCurrent(operation)) return null;

    _emit(
      _uiState.copyWith(
        mode: mode,
        statusText: statusText,
        titleText: titleText,
        subtitleText: subtitleText,
        isBusy: true,
        hasResult: false,
        clearRecognizedText: true,
      ),
    );

    try {
      await _session!.stopStream();

      if (!_isCurrent(operation)) return null;

      final shot = await _session!.takePicture(resumeStream: false);

      if (!_isCurrent(operation)) return null;

      if (shot == null) {
        throw Exception('فشل تصوير الصورة');
      }

      await _speakInstruction(operation: operation, text: speakText);

      return shot;
    } catch (e) {
      if (!_isCurrent(operation)) return null;

      _busy = false;

      _emit(
        _uiState.copyWith(
          mode: mode,
          statusText: 'فشل التصوير',
          titleText: 'Camera Error',
          subtitleText: e.toString(),
          isBusy: false,
          hasResult: false,
          clearRecognizedText: true,
        ),
      );

      await _speakInstruction(
        operation: operation,
        text: 'فشل تصوير الصورة. للقراءة مرة أخرى قل تصوير.',
      );

      return null;
    }
  }

  Future<void> repeatCurrentText() async {
    final operation = ++_operationId;

    final text = _uiState.recognizedText.trim();

    if (text.isEmpty) {
      await _speakInstruction(
        operation: operation,
        text: 'لا يوجد نص مقروء الآن.',
      );
      return;
    }

    await _speakResult(operation: operation, text: text);
  }

  Future<void> toggleTorch() async {
    final operation = ++_operationId;

    final rawController = _session?.rawController();

    if (rawController == null || !rawController.value.isInitialized) {
      await _speakInstruction(
        operation: operation,
        text: 'الفلاش غير جاهز الآن.',
      );
      return;
    }

    final nextTorchState = !_uiState.isTorchOn;

    try {
      await rawController.setFlashMode(
        nextTorchState ? FlashMode.torch : FlashMode.off,
      );

      _autoFlashService.setKnownTorchState(nextTorchState);

      _emit(_uiState.copyWith(isTorchOn: nextTorchState));

      await _speakInstruction(
        operation: operation,
        text: nextTorchState ? 'تم تشغيل الفلاش.' : 'تم إيقاف الفلاش.',
      );
    } catch (_) {
      await _speakInstruction(
        operation: operation,
        text: 'تعذر تغيير حالة الفلاش.',
      );
    }
  }

  int? _beginAction() {
    if (_disposed) return null;
    if (!_uiState.isCameraAllowed) return null;

    if (_busy || _uiState.isBusy) return null;

    final now = DateTime.now();

    if (now.difference(_lastActionTime).inMilliseconds < 250) {
      return null;
    }

    _lastActionTime = now;
    _busy = true;

    return ++_operationId;
  }

  bool _isCurrent(int operation) {
    return !_disposed && operation == _operationId;
  }

  Future<bool> _checkInternetFast() async {
    return NetworkCheckService.hasInternetConnection(
      timeout: const Duration(seconds: 2),
    );
  }

  Future<bool> _checkInternetForOperation(int operation) async {
    _emit(
      _uiState.copyWith(
        statusText: 'جاري فحص الإنترنت',
        titleText: 'قارئ النصوص',
        subtitleText: 'ثواني وهنحدد القراءة من السيرفر ولا أوفلاين',
        isBusy: true,
        hasResult: false,
        clearRecognizedText: true,
      ),
    );

    final hasInternet = await _checkInternetFast();

    if (!_isCurrent(operation)) return false;

    _lastKnownHasInternet = hasInternet;

    return hasInternet;
  }

  Future<void> _speakInstruction({
    required int operation,
    required String text,
  }) async {
    if (!_isCurrent(operation)) return;

    await _ttsService.speakInstruction(text);

    if (!_isCurrent(operation)) return;
  }

  Future<void> _speakResult({
    required int operation,
    required String text,
  }) async {
    if (!_isCurrent(operation)) return;

    await _stopAllSpeech();

    if (!_isCurrent(operation)) return;

    await _ttsService.speakExtractedText(text);

    if (!_isCurrent(operation)) return;

    await _ttsService.speakInstruction(
      'للقراءة مرة أخرى قل تصوير. وللإغلاق قل إغلاق.',
    );

    if (!_isCurrent(operation)) return;
  }

  Future<void> _stopAllSpeech() async {
    await _englishOcrService.stopSpeaking();
    await _ttsService.stop();
  }

  Future<void> _finishAction(int operation) async {
    if (!_isCurrent(operation)) return;

    _busy = false;

    try {
      await _session?.startStream();
    } catch (_) {}
  }

  void _emit(TextReaderUiState newState) {
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

    _englishOcrService.dispose();
    await _ttsService.dispose();
  }
}
