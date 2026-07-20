import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/tts/arabic_tts_normalizer.dart';
import '../../../core/tts/tts_voice_prefs.dart';

class TextReaderTtsService {
  final FlutterTts _tts = FlutterTts();

  late final Future<void> _ttsReady;

  bool _disposed = false;

  Map<String, String>? _cachedEnglishVoice;
  String? _lastAppliedVoiceKey;

  static const double _instructionSpeechRate = 0.50;
  static const double _readingSpeechRate = 0.40;

  TextReaderTtsService() {
    _ttsReady = _initTts();
  }

  Future<void> init() async {
    await _ttsReady;
  }

  Future<void> _initTts() async {
    if (Platform.isIOS) {
      await _tts.setSharedInstance(true);
    }

    await _tts.awaitSpeakCompletion(true);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(_instructionSpeechRate);

    await _applySelectedVoice(force: true);
  }

  Future<void> speakInstruction(String text) async {
    await _speakWithSelectedVoice(text, rate: _instructionSpeechRate);
  }

  Future<void> speakExtractedText(String text) async {
    await _speakMixedText(text, rate: _readingSpeechRate);
  }

  Future<void> _speakWithSelectedVoice(
    String text, {
    required double rate,
  }) async {
    if (_disposed) return;

    final clean = text.trim();
    if (clean.isEmpty) return;

    await init();

    if (_disposed) return;

    try {
      await _tts.stop();
      await _tts.awaitSpeakCompletion(true);
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(rate);

      await _applySelectedVoice(force: true);

      await _tts.speak(ArabicTtsNormalizer.prepare(clean));
    } catch (_) {
      // منخليش مشكلة الصوت توقف الفيتشر.
    }
  }

  Future<void> _speakMixedText(String text, {required double rate}) async {
    if (_disposed) return;

    final clean = text.trim();
    if (clean.isEmpty) return;

    await init();

    if (_disposed) return;

    try {
      await _tts.stop();
      await _tts.awaitSpeakCompletion(true);
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(rate);

      final chunks = _buildMixedLanguageChunks(clean);

      if (chunks.isEmpty) {
        await _applySelectedVoice(force: true);
        await _tts.speak(ArabicTtsNormalizer.prepare(clean));
        return;
      }

      for (final chunk in chunks) {
        if (_disposed) return;

        final chunkText = chunk.text.trim();
        if (chunkText.isEmpty) continue;

        if (chunk.language == _TextSpeechLanguage.english) {
          await _applyBestEnglishVoice();
          await _tts.speak(chunkText);
        } else {
          await _applySelectedVoice();
          await _tts.speak(ArabicTtsNormalizer.prepare(chunkText));
        }
      }
    } catch (_) {
      try {
        if (_disposed) return;

        await _tts.stop();
        await _tts.awaitSpeakCompletion(true);
        await _tts.setPitch(1.0);
        await _tts.setSpeechRate(rate);
        await _applySelectedVoice(force: true);
        await _tts.speak(ArabicTtsNormalizer.prepare(clean));
      } catch (_) {}
    }
  }

  List<_TextSpeechChunk> _buildMixedLanguageChunks(String text) {
    final chunks = <_TextSpeechChunk>[];
    final buffer = StringBuffer();

    _TextSpeechLanguage? currentLanguage;
    _TextSpeechLanguage? lastStrongLanguage;

    void flushBuffer() {
      final chunkText = buffer.toString();

      if (chunkText.trim().isNotEmpty) {
        chunks.add(
          _TextSpeechChunk(
            text: chunkText,
            language:
                currentLanguage ??
                lastStrongLanguage ??
                _TextSpeechLanguage.arabic,
          ),
        );
      }

      buffer.clear();
    }

    for (final rune in text.runes) {
      final detectedLanguage = _detectRuneLanguage(rune);

      if (detectedLanguage == null) {
        currentLanguage ??= lastStrongLanguage ?? _TextSpeechLanguage.arabic;
        buffer.writeCharCode(rune);
        continue;
      }

      if (currentLanguage == null) {
        currentLanguage = detectedLanguage;
        lastStrongLanguage = detectedLanguage;
        buffer.writeCharCode(rune);
        continue;
      }

      if (currentLanguage != detectedLanguage) {
        flushBuffer();
        currentLanguage = detectedLanguage;
      }

      lastStrongLanguage = detectedLanguage;
      buffer.writeCharCode(rune);
    }

    flushBuffer();

    return _mergeTinyChunks(chunks);
  }

  List<_TextSpeechChunk> _mergeTinyChunks(List<_TextSpeechChunk> chunks) {
    if (chunks.length <= 1) return chunks;

    final merged = <_TextSpeechChunk>[];

    for (final chunk in chunks) {
      if (merged.isEmpty) {
        merged.add(chunk);
        continue;
      }

      final previous = merged.last;

      if (previous.language == chunk.language) {
        merged[merged.length - 1] = _TextSpeechChunk(
          text: '${previous.text} ${chunk.text}',
          language: previous.language,
        );
        continue;
      }

      final previousClean = previous.text.trim();
      final currentClean = chunk.text.trim();

      final previousIsOnlySymbols =
          !_hasArabicLetters(previousClean) &&
          !_hasEnglishLetters(previousClean);

      final currentIsOnlySymbols =
          !_hasArabicLetters(currentClean) && !_hasEnglishLetters(currentClean);

      if (previousIsOnlySymbols) {
        merged[merged.length - 1] = _TextSpeechChunk(
          text: '${previous.text} ${chunk.text}',
          language: chunk.language,
        );
        continue;
      }

      if (currentIsOnlySymbols && merged.isNotEmpty) {
        merged[merged.length - 1] = _TextSpeechChunk(
          text: '${previous.text} ${chunk.text}',
          language: previous.language,
        );
        continue;
      }

      merged.add(chunk);
    }

    return merged;
  }

  _TextSpeechLanguage? _detectRuneLanguage(int rune) {
    if (_isArabicRune(rune)) {
      return _TextSpeechLanguage.arabic;
    }

    if (_isEnglishRune(rune)) {
      return _TextSpeechLanguage.english;
    }

    return null;
  }

  bool _isArabicRune(int rune) {
    return (rune >= 0x0600 && rune <= 0x06FF) ||
        (rune >= 0x0750 && rune <= 0x077F) ||
        (rune >= 0x08A0 && rune <= 0x08FF) ||
        (rune >= 0xFB50 && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF);
  }

  bool _isEnglishRune(int rune) {
    return (rune >= 0x0041 && rune <= 0x005A) ||
        (rune >= 0x0061 && rune <= 0x007A);
  }

  bool _hasArabicLetters(String text) {
    return RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]').hasMatch(text);
  }

  bool _hasEnglishLetters(String text) {
    return RegExp(r'[A-Za-z]').hasMatch(text);
  }

  Future<void> _applySelectedVoice({bool force = false}) async {
    if (!force && _lastAppliedVoiceKey == 'saved_arabic_voice') return;

    final applied = await TtsVoicePrefs.applySavedVoice(_tts);

    if (!applied) {
      await _tts.setLanguage('ar-EG');
    }

    _lastAppliedVoiceKey = 'saved_arabic_voice';
  }

  Future<void> _applyBestEnglishVoice() async {
    const fallbackLanguage = 'en-US';

    try {
      final selectedVoice =
          _cachedEnglishVoice ?? await _findBestEnglishVoice();
      _cachedEnglishVoice = selectedVoice;

      if (selectedVoice != null) {
        final name = selectedVoice['name'] ?? '';
        final locale = selectedVoice['locale'] ?? fallbackLanguage;
        final voiceKey = 'english_voice:$locale:$name';

        if (_lastAppliedVoiceKey != voiceKey) {
          await _tts.setLanguage(locale);
          await _tts.setVoice({'name': name, 'locale': locale});

          _lastAppliedVoiceKey = voiceKey;
        }

        return;
      }

      if (_lastAppliedVoiceKey != 'english_language:$fallbackLanguage') {
        await _tts.setLanguage(fallbackLanguage);
        _lastAppliedVoiceKey = 'english_language:$fallbackLanguage';
      }
    } catch (_) {
      try {
        if (_lastAppliedVoiceKey != 'english_language:$fallbackLanguage') {
          await _tts.setLanguage(fallbackLanguage);
          _lastAppliedVoiceKey = 'english_language:$fallbackLanguage';
        }
      } catch (_) {}
    }
  }

  Future<Map<String, String>?> _findBestEnglishVoice() async {
    final rawVoices = await _tts.getVoices;
    final voices = <Map<String, String>>[];

    if (rawVoices is List) {
      for (final voice in rawVoices) {
        if (voice is Map) {
          final name = (voice['name'] ?? '').toString().trim();
          final locale = (voice['locale'] ?? '').toString().trim();

          if (name.isEmpty || locale.isEmpty) continue;

          final localeLower = locale.toLowerCase();

          if (localeLower.startsWith('en')) {
            voices.add({'name': name, 'locale': locale});
          }
        }
      }
    }

    return _pickBestEnglishVoice(voices);
  }

  Map<String, String>? _pickBestEnglishVoice(List<Map<String, String>> voices) {
    if (voices.isEmpty) return null;

    Map<String, String>? bestVoice;
    var bestScore = -1;

    for (final voice in voices) {
      final name = (voice['name'] ?? '').toLowerCase();
      final locale = (voice['locale'] ?? '').toLowerCase();

      var score = 0;

      if (locale == 'en-us') score += 100;
      if (locale == 'en-gb') score += 90;
      if (locale.startsWith('en-us')) score += 80;
      if (locale.startsWith('en-gb')) score += 70;
      if (locale.startsWith('en')) score += 50;

      if (name.contains('google')) score += 25;
      if (name.contains('network')) score += 20;
      if (name.contains('enhanced')) score += 18;
      if (name.contains('premium')) score += 18;
      if (name.contains('female')) score += 8;
      if (name.contains('male')) score += 6;

      if (score > bestScore) {
        bestScore = score;
        bestVoice = voice;
      }
    }

    return bestVoice;
  }

  Future<void> stop() async {
    if (_disposed) return;

    await init();

    try {
      await _tts.stop();
      await _tts.setSpeechRate(_instructionSpeechRate);
      _lastAppliedVoiceKey = null;
    } catch (_) {}
  }

  Future<void> dispose() async {
    _disposed = true;

    try {
      await _tts.stop();
    } catch (_) {}
  }
}

enum _TextSpeechLanguage { arabic, english }

class _TextSpeechChunk {
  final String text;
  final _TextSpeechLanguage language;

  const _TextSpeechChunk({required this.text, required this.language});
}
