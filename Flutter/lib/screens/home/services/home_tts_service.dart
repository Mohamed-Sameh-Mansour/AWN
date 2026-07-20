import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/tts/arabic_tts_normalizer.dart';
import '../../../core/tts/tts_voice_prefs.dart';

class HomeTtsService {
  final FlutterTts _tts = FlutterTts();

  late final Future<void> ready = _init();

  int _speechSerial = 0;
  bool _disposed = false;

  Future<void> _init() async {
    await _tts.setLanguage('ar-EG');
    await _tts.setSpeechRate(0.55);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(false);
    await TtsVoicePrefs.applySavedVoice(_tts);
  }

  Future<void> refreshVoice() async {
    if (_disposed) return;

    try {
      await ready;
      await TtsVoicePrefs.applySavedVoice(_tts);
    } catch (_) {}
  }

  Future<void> stop() async {
    _speechSerial++;

    try {
      await ready;
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> speak(
    String text, {
    Duration delayBeforeSpeak = Duration.zero,
    bool Function()? canSpeak,
  }) async {
    final cleanText = text.trim();

    if (cleanText.isEmpty) return;
    if (_disposed) return;

    final int mySerial = ++_speechSerial;

    try {
      await ready;
    } catch (_) {}

    if (_disposed) return;
    if (mySerial != _speechSerial) return;

    if (delayBeforeSpeak > Duration.zero) {
      await Future.delayed(delayBeforeSpeak);
    }

    if (_disposed) return;
    if (mySerial != _speechSerial) return;
    if (canSpeak != null && !canSpeak()) return;

    try {
      await _tts.stop();
    } catch (_) {}

    if (_disposed) return;
    if (mySerial != _speechSerial) return;
    if (canSpeak != null && !canSpeak()) return;

    try {
      await _tts.speak(ArabicTtsNormalizer.prepare(cleanText));
    } catch (_) {}
  }

  void dispose() {
    _disposed = true;
    _speechSerial++;

    try {
      _tts.stop();
    } catch (_) {}
  }
}
