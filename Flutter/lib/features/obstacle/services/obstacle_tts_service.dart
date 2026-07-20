import 'package:flutter_tts/flutter_tts.dart';

import 'package:myeye/core/tts/arabic_tts_normalizer.dart';
import 'package:myeye/core/tts/tts_voice_prefs.dart';

class ObstacleTtsService {
  final FlutterTts _tts = FlutterTts();

  bool _ready = false;
  bool _speaking = false;

  bool get isReady => _ready;
  bool get isSpeaking => _speaking;

  Future<void> init() async {
    _tts.setStartHandler(() => _speaking = true);
    _tts.setCompletionHandler(() => _speaking = false);
    _tts.setCancelHandler(() => _speaking = false);
    _tts.setErrorHandler((_) => _speaking = false);

    await _tts.setLanguage('ar-EG');
    await _tts.setSpeechRate(0.50);
    await _tts.setPitch(1.0);

    await _tts.awaitSpeakCompletion(false);

    await TtsVoicePrefs.applySavedVoice(_tts);

    _ready = true;
  }

  Future<void> speakIntro(String text) async {
    if (!_ready) return;

    await stop();

    try {
      await _tts.awaitSpeakCompletion(true);
      _speaking = true;
      await _tts.speak(ArabicTtsNormalizer.prepare(text));
    } catch (_) {
      // تجاهل أي خطأ صوتي عشان الفيتشر نفسها ماتقفش.
    } finally {
      _speaking = false;

      try {
        await _tts.awaitSpeakCompletion(false);
      } catch (_) {}
    }
  }

  Future<void> speakWarning(String text) async {
    if (!_ready) return;

    await _tts.stop();
    _speaking = false;

    await _tts.speak(ArabicTtsNormalizer.prepare(text));
  }

  Future<void> speakGuide(String text) async {
    if (!_ready || _speaking) return;

    await _tts.speak(ArabicTtsNormalizer.prepare(text));
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}

    _speaking = false;
  }

  Future<void> dispose() async {
    await stop();
  }
}
