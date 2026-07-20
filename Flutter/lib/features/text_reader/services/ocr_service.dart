import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:myeye/core/tts/tts_voice_prefs.dart';

class OcrService {
  final TextRecognizer _latinRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  final FlutterTts _tts = FlutterTts();

  bool _disposed = false;
  bool _introSpoken = false;

  late final Future<void> _ttsReady;

  static const double _instructionSpeechRate = 0.50;
  static const double _readingSpeechRate = 0.40;

  OcrService() {
    _ttsReady = _initTts();
  }

  Future<void> _initTts() async {
    if (Platform.isIOS) {
      await _tts.setSharedInstance(true);
    }

    await _tts.awaitSpeakCompletion(true);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(_instructionSpeechRate);

    await _applySelectedVoice(fallbackLanguage: 'ar-EG');
  }

  Future<void> _ensureTtsReady() async {
    await _ttsReady;
  }

  Future<void> stopSpeaking() async {
    if (_disposed) return;

    await _ensureTtsReady();

    try {
      await _tts.stop();
      await _tts.setSpeechRate(_instructionSpeechRate);
    } catch (_) {}
  }

  Future<void> speakOnce(String text) async {
    if (_introSpoken) return;

    _introSpoken = true;

    await speakArabic(text);
  }

  Future<void> speakArabic(String text) async {
    await _speakWithSelectedVoice(
      text,
      rate: _instructionSpeechRate,
      fallbackLanguage: 'ar-EG',
    );
  }

  Future<void> speakEnglish(String text) async {
    await _speakWithEnglishVoice(text, rate: _readingSpeechRate);
  }

  Future<void> _speakWithSelectedVoice(
    String text, {
    required double rate,
    required String fallbackLanguage,
  }) async {
    if (_disposed) return;

    final clean = text.trim();
    if (clean.isEmpty) return;

    await _ensureTtsReady();

    if (_disposed) return;

    try {
      await _tts.stop();
      await _tts.awaitSpeakCompletion(true);
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(rate);

      await _applySelectedVoice(fallbackLanguage: fallbackLanguage);

      await _tts.speak(clean);
    } catch (_) {
      // منخليش مشكلة الصوت توقف الفيتشر.
    }
  }

  Future<void> _speakWithEnglishVoice(
    String text, {
    required double rate,
  }) async {
    if (_disposed) return;

    final clean = text.trim();
    if (clean.isEmpty) return;

    await _ensureTtsReady();

    if (_disposed) return;

    try {
      await _tts.stop();
      await _tts.awaitSpeakCompletion(true);
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(rate);

      await _applyBestEnglishVoice();

      await _tts.speak(clean);
    } catch (_) {
      // منخليش مشكلة الصوت توقف الفيتشر.
    }
  }

  Future<void> _applySelectedVoice({required String fallbackLanguage}) async {
    final applied = await TtsVoicePrefs.applySavedVoice(_tts);

    if (!applied) {
      await _tts.setLanguage(fallbackLanguage);
    }
  }

  Future<void> _applyBestEnglishVoice() async {
    const fallbackLanguage = 'en-US';

    try {
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

      final selectedVoice = _pickBestEnglishVoice(voices);

      if (selectedVoice != null) {
        final name = selectedVoice['name'] ?? '';
        final locale = selectedVoice['locale'] ?? fallbackLanguage;

        await _tts.setLanguage(locale);
        await _tts.setVoice({'name': name, 'locale': locale});

        return;
      }

      await _tts.setLanguage(fallbackLanguage);
    } catch (_) {
      try {
        await _tts.setLanguage(fallbackLanguage);
      } catch (_) {}
    }
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

  Future<String> extractEnglishFromImageFile(String imagePath) async {
    final file = File(imagePath);

    if (!await file.exists()) {
      throw const OcrException('ملف الصورة غير موجود');
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _latinRecognizer.processImage(inputImage);

      final cleaned = _cleanText(recognizedText.text);

      if (cleaned.isEmpty || !_hasLatinOrDigits(cleaned)) {
        throw const OcrException('لم يتم العثور على نص إنجليزي واضح');
      }

      HapticFeedback.lightImpact();

      return cleaned;
    } catch (e) {
      if (e is OcrException) rethrow;

      throw OcrException('فشل قراءة النص الإنجليزي: $e');
    }
  }

  String _cleanText(String text) {
    var clean = text.replaceAll('\n', ' ').trim();
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');
    return clean;
  }

  bool _hasLatinOrDigits(String text) {
    return RegExp(r'[A-Za-z0-9]').hasMatch(text);
  }

  void dispose() {
    _disposed = true;

    try {
      _latinRecognizer.close();
      _tts.stop();
    } catch (_) {}
  }
}

class OcrException implements Exception {
  final String message;

  const OcrException(this.message);

  @override
  String toString() => message;
}
