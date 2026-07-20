import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'package:myeye/core/constants/app_constants.dart';
import 'package:myeye/core/tts/arabic_tts_normalizer.dart';
import 'package:myeye/core/tts/tts_voice_prefs.dart';

class CurrencyTtsService {
  final FlutterTts _tts = FlutterTts();

  bool _speaking = false;
  bool _finalSpeechActive = false;
  bool _disposed = false;

  DateTime _lastGuideAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFallbackGuideAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastAnySpeechFinishedAt = DateTime.fromMillisecondsSinceEpoch(0);

  String _lastGuideText = '';

  String? _pendingGuideText;
  bool _pendingGuideIsFallback = false;

  bool get isFinalSpeechActive => _finalSpeechActive;

  Future<void> init() async {
    await _tts.setLanguage('ar-EG');
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    await TtsVoicePrefs.applySavedVoice(_tts);
  }

  Future<void> speakGuide(String text, {required bool isFallback}) async {
    if (_disposed) return;
    if (_finalSpeechActive) return;

    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final now = DateTime.now();

    if (isFallback) {
      if (now.difference(_lastFallbackGuideAt).inMilliseconds <
          CurrencyConstants.fallbackCooldownMs) {
        return;
      }
    }

    if (cleanText == _lastGuideText &&
        now.difference(_lastGuideAt).inMilliseconds <
            CurrencyConstants.guideCooldownMs) {
      return;
    }

    if (_speaking) {
      _pendingGuideText = cleanText;
      _pendingGuideIsFallback = isFallback;
      return;
    }

    final gap = now.difference(_lastAnySpeechFinishedAt).inMilliseconds;

    if (gap < 250) {
      _pendingGuideText = cleanText;
      _pendingGuideIsFallback = isFallback;
      return;
    }

    _startGuideSpeech(cleanText, isFallback: isFallback);
  }

  void _startGuideSpeech(String text, {required bool isFallback}) {
    if (_disposed) return;
    if (_finalSpeechActive) return;
    if (_speaking) return;

    _lastGuideText = text;
    _lastGuideAt = DateTime.now();

    if (isFallback) {
      _lastFallbackGuideAt = DateTime.now();
    }

    unawaited(_runSpeech(text, afterDone: _speakPendingGuideIfNeeded));
  }

  Future<void> _speakPendingGuideIfNeeded() async {
    if (_disposed) return;
    if (_finalSpeechActive) return;
    if (_speaking) return;

    final pendingText = _pendingGuideText;
    final pendingIsFallback = _pendingGuideIsFallback;

    if (pendingText == null || pendingText.trim().isEmpty) {
      return;
    }

    _pendingGuideText = null;
    _pendingGuideIsFallback = false;

    await Future.delayed(const Duration(milliseconds: 180));

    if (_disposed) return;
    if (_finalSpeechActive) return;
    if (_speaking) return;

    _startGuideSpeech(pendingText, isFallback: pendingIsFallback);
  }

  Future<void> speakFinal(String text) async {
    if (_disposed) return;

    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    _finalSpeechActive = true;
    _pendingGuideText = null;
    _pendingGuideIsFallback = false;

    try {
      await _tts.stop();
    } catch (_) {}

    _speaking = false;

    await _runSpeech(cleanText);

    _finalSpeechActive = false;
  }

  void speakDuringCapture(String text) {
    if (_disposed) return;
    if (_finalSpeechActive) return;
    if (_speaking) return;

    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    unawaited(_runSpeech(cleanText));
  }

  Future<void> _runSpeech(
    String text, {
    Future<void> Function()? afterDone,
  }) async {
    if (_disposed) return;
    if (_speaking) return;

    _speaking = true;

    try {
      await _tts.speak(ArabicTtsNormalizer.prepare(text));
    } catch (_) {
      // منخليش مشكلة الصوت توقف التطبيق.
    } finally {
      _speaking = false;
      _lastAnySpeechFinishedAt = DateTime.now();

      if (afterDone != null) {
        await afterDone();
      }
    }
  }

  Future<void> stop() async {
    _pendingGuideText = null;
    _pendingGuideIsFallback = false;

    try {
      await _tts.stop();
    } catch (_) {}

    _speaking = false;
    _finalSpeechActive = false;
  }

  void dispose() {
    _disposed = true;
    _pendingGuideText = null;
    _pendingGuideIsFallback = false;
    _tts.stop();
  }
}
