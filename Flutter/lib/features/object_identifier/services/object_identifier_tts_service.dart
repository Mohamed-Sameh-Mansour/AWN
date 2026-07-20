import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/tts/arabic_tts_normalizer.dart';
import '../../../core/tts/tts_voice_prefs.dart';

class ObjectIdentifierTtsService {
  final FlutterTts _tts = FlutterTts();

  bool _isReady = false;
  bool _disposed = false;

  Future<void> init() async {
    if (_isReady || _disposed) return;

    await _tts.setLanguage('ar-EG');
    await _tts.setSpeechRate(0.50);
    await _tts.setPitch(1.0);

    await _tts.awaitSpeakCompletion(true);

    await TtsVoicePrefs.applySavedVoice(_tts);

    _isReady = true;
  }

  Future<void> speak(String text) async {
    final cleanText = text.trim();

    if (cleanText.isEmpty || _disposed) return;

    await init();

    if (_disposed) return;

    try {
      await _tts.stop();
    } catch (_) {}

    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(ArabicTtsNormalizer.prepare(cleanText));
    } catch (_) {
      // منخليش مشكلة الصوت توقف الفيتشر.
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
  }
}
