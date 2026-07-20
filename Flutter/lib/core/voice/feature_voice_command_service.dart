import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:myeye/core/permissions/permission_service.dart';

class FeatureVoiceCommand {
  final String id;
  final List<String> phrases;

  const FeatureVoiceCommand({required this.id, required this.phrases});

  bool matches(String normalizedText) {
    if (normalizedText.isEmpty) return false;

    final words = normalizedText
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .toList();

    if (words.isEmpty) return false;

    /*
      حماية بسيطة من إن التطبيق يسمع جملة التعليمات بتاعته
      زي: "قل تصوير" أو "للإغلاق قل إغلاق"
      ويتعامل معاها كأمر من المستخدم.
    */
    if (_looksLikeAppInstruction(normalizedText, words)) {
      return false;
    }

    final compactText = normalizedText.replaceAll(' ', '');

    for (final phrase in phrases) {
      final normalizedPhrase = FeatureVoiceCommandService.normalize(phrase);
      if (normalizedPhrase.isEmpty) continue;

      final compactPhrase = normalizedPhrase.replaceAll(' ', '');

      if (normalizedText == normalizedPhrase) return true;
      if (compactText == compactPhrase) return true;

      /*
        مثال:
        المستخدم يقول: "عايز تصوير"
        أو الـ Speech يرجع: "التصوير"
        فلو الكلمة الأساسية موجودة بوضوح نعتبرها Match.
      */
      if (compactPhrase.length >= 3 && compactText.contains(compactPhrase)) {
        return true;
      }

      if (words.contains(normalizedPhrase)) {
        return true;
      }
    }

    return false;
  }

  bool _looksLikeAppInstruction(String normalizedText, List<String> words) {
    if (words.length <= 2) return false;

    const instructionWords = [
      'قل',
      'للتشغيل',
      'للاقلاع',
      'للبدا',
      'للقراءه',
      'للتحديد',
      'للكشف',
      'لاغلاق',
      'للاغلاق',
      'للخروج',
      'اضغط',
      'مرتين',
      'او',
    ];

    return instructionWords.any((word) => normalizedText.contains(word));
  }
}

class FeatureVoiceCommandIds {
  static const String start = 'start';
  static const String exit = 'exit';

  /*
    دول سايبينهم عشان لو في كود قديم لسه بيستخدمهم.
    لكن بعد تنظيم قارئ النصوص، المفروض الاستخدام الأساسي يبقى start / exit.
  */
  static const String english = 'english';
  static const String arabic = 'arabic';
}

class VoiceCommandPhrases {
  static const List<String> capture = ['تصوير', 'صور', 'صورة', 'صوره'];

  static const List<String> exit = ['اغلاق', 'إغلاق', 'غلق', 'اغلق', 'إغلق'];
}

typedef FeatureVoiceCommandCallback =
    FutureOr<void> Function(String commandId, String recognizedText);

class FeatureVoiceCommandService {
  FeatureVoiceCommandService({required this.debugName});

  final String debugName;

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _permissionTts = FlutterTts();

  List<FeatureVoiceCommand> _commands = const [];
  FeatureVoiceCommandCallback? _onCommand;

  bool _available = false;
  bool _active = false;
  bool _listening = false;
  bool _handlingCommand = false;
  bool _disposed = false;
  bool _permissionTtsReady = false;

  String _localeId = 'ar_EG';
  Duration _listenFor = const Duration(seconds: 18);
  Duration _pauseFor = const Duration(seconds: 3);

  Timer? _restartTimer;
  DateTime _lastCommandAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastNormalizedText = '';

  bool get isActive => _active;
  bool get isListening => _listening;
  bool get isAvailable => _available;

  Future<bool> start({
    required List<FeatureVoiceCommand> commands,
    required FeatureVoiceCommandCallback onCommand,
    String localeId = 'ar_EG',
    Duration listenFor = const Duration(seconds: 18),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (_disposed) return false;

    _commands = commands;
    _onCommand = onCommand;
    _localeId = localeId;
    _listenFor = listenFor;
    _pauseFor = pauseFor;
    _active = true;

    final hasMicPermission = await PermissionService.ensureMicrophonePermission(
      speak: _speakPermissionMessage,
    );

    if (!hasMicPermission) {
      _active = false;
      _available = false;
      return false;
    }

    if (!_available) {
      _available = await _speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        debugLogging: kDebugMode,
      );
    }

    if (!_available || !_active || _disposed) {
      return false;
    }

    await _restartListening(after: const Duration(milliseconds: 250));
    return true;
  }

  Future<void> _speakPermissionMessage(String message) async {
    if (_disposed) return;

    try {
      if (!_permissionTtsReady) {
        await _permissionTts.setLanguage('ar-EG');
        await _permissionTts.setSpeechRate(0.50);
        await _permissionTts.setPitch(1.0);
        await _permissionTts.awaitSpeakCompletion(true);
        _permissionTtsReady = true;
      }

      await _permissionTts.stop();
      await _permissionTts.speak(message);
    } catch (_) {
      /*
        الصوت هنا مساعد فقط.
        لو حصل خطأ في TTS ماينفعش نوقف طلب الإذن.
      */
    }
  }

  void replaceCommands(List<FeatureVoiceCommand> commands) {
    if (_disposed) return;

    _commands = commands;
    _lastNormalizedText = '';
  }

  Future<void> stop() async {
    _active = false;
    _restartTimer?.cancel();
    _restartTimer = null;

    if (_listening || _speech.isListening) {
      try {
        await _speech.stop();
      } catch (_) {}
    }

    _listening = false;
  }

  Future<void> pause() async {
    _restartTimer?.cancel();
    _restartTimer = null;

    if (_listening || _speech.isListening) {
      try {
        await _speech.stop();
      } catch (_) {}
    }

    _listening = false;
  }

  Future<void> resume({
    Duration after = const Duration(milliseconds: 650),
  }) async {
    if (!_active || _disposed || !_available) return;

    await _restartListening(after: after);
  }

  Future<void> dispose() async {
    _disposed = true;

    try {
      await _permissionTts.stop();
    } catch (_) {}

    await stop();
  }

  void _handleStatus(String status) {
    if (_disposed) return;

    final cleanStatus = status.toLowerCase().trim();

    if (cleanStatus == 'listening') {
      _listening = true;
      return;
    }

    if (cleanStatus == 'notlistening' ||
        cleanStatus == 'done' ||
        cleanStatus == 'done_no_result') {
      _listening = false;

      if (_active && !_handlingCommand) {
        unawaited(_restartListening(after: const Duration(milliseconds: 450)));
      }
    }
  }

  void _handleError(SpeechRecognitionError error) {
    if (_disposed) return;

    _listening = false;

    if (_active && !_handlingCommand) {
      unawaited(_restartListening(after: const Duration(milliseconds: 750)));
    }
  }

  Future<void> _restartListening({required Duration after}) async {
    if (_disposed || !_active || !_available || _handlingCommand) return;

    _restartTimer?.cancel();

    _restartTimer = Timer(after, () {
      if (_disposed || !_active || !_available || _handlingCommand) return;

      unawaited(_listenOnce());
    });
  }

  Future<void> _listenOnce() async {
    if (_disposed || !_active || !_available || _handlingCommand) return;

    try {
      if (_speech.isListening) return;

      _listening = true;

      await _speech.listen(
        onResult: _handleResult,
        listenOptions: stt.SpeechListenOptions(
          localeId: _localeId,
          listenFor: _listenFor,
          pauseFor: _pauseFor,
          partialResults: true,
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: false,
        ),
      );
    } catch (_) {
      _listening = false;

      if (_active && !_handlingCommand) {
        await _restartListening(after: const Duration(milliseconds: 750));
      }
    }
  }

  void _handleResult(SpeechRecognitionResult result) {
    if (_disposed || !_active || _handlingCommand) return;

    final recognizedText = result.recognizedWords.trim();
    final normalizedText = normalize(recognizedText);

    if (normalizedText.isEmpty) return;

    if (kDebugMode) {
      debugPrint(
        '[$debugName voice] heard="$recognizedText" normalized="$normalizedText"',
      );
    }

    final now = DateTime.now();

    if (normalizedText == _lastNormalizedText &&
        now.difference(_lastCommandAt).inMilliseconds < 1000) {
      return;
    }

    final commandsSnapshot = List<FeatureVoiceCommand>.from(_commands);

    for (final command in commandsSnapshot) {
      if (!command.matches(normalizedText)) continue;

      if (now.difference(_lastCommandAt).inMilliseconds < 1100) {
        return;
      }

      _lastCommandAt = now;
      _lastNormalizedText = normalizedText;

      unawaited(_executeCommand(command.id, recognizedText));
      return;
    }
  }

  Future<void> _executeCommand(String commandId, String recognizedText) async {
    if (_disposed) return;

    _handlingCommand = true;

    try {
      await pause();
      await _onCommand?.call(commandId, recognizedText);
    } catch (_) {
      /*
        الأوامر الصوتية اختيارية.
        لو حصل خطأ، ماينفعش نوقع الفيتشر كله.
      */
    } finally {
      _handlingCommand = false;

      if (_active && !_disposed) {
        await resume(after: const Duration(milliseconds: 650));
      }
    }
  }

  static String normalize(String value) {
    var text = value.toLowerCase().trim();

    text = text
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ئ', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ة', 'ه');

    text = text.replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9 ]+'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }
}

class FeatureVoiceCommandPresets {
  static const List<FeatureVoiceCommand> startOnly = [
    FeatureVoiceCommand(
      id: FeatureVoiceCommandIds.start,
      phrases: VoiceCommandPhrases.capture,
    ),
  ];

  static const List<FeatureVoiceCommand> exitOnly = [
    FeatureVoiceCommand(
      id: FeatureVoiceCommandIds.exit,
      phrases: VoiceCommandPhrases.exit,
    ),
  ];

  static const List<FeatureVoiceCommand> startAndExit = [
    ...startOnly,
    ...exitOnly,
  ];

  static const List<FeatureVoiceCommand> captureOnly = startOnly;

  static const List<FeatureVoiceCommand> captureAndExit = startAndExit;

  /*
    بعد تنظيم قارئ النصوص، أوامره المفروض تبقى تصوير / إغلاق.
    سايبين الاسم textReader عشان لو أي شاشة لسه بتستدعيه مايحصلش Compile Error.
  */
  static const List<FeatureVoiceCommand> textReader = startAndExit;

  /*
    سايبينها للتوافق مع أي كود قديم فقط.
    يفضل عدم استخدامها في النسخة الجديدة.
  */
  static const List<FeatureVoiceCommand> textReaderNoExit = startOnly;
}
