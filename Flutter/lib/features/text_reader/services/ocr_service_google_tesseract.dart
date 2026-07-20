import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:flutter_tts/flutter_tts.dart';

class OcrService {
  final TextRecognizer _googleRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final FlutterTts _flutterTts = FlutterTts();

  // Stream لإرسال النص المعالج لواجهة المستخدم
  final _textStreamController = StreamController<String>.broadcast();
  Stream<String> get onTextFound => _textStreamController.stream;

  bool _isBusy = false; 
  String _lastReadText = "";
  DateTime _lastReadTime = DateTime.now();
  String _currentLanguage = "ar-EG";
  
  // متغير للتحكم في وقت تنبيه النص العربي حتى لا يزعج المستخدم
  DateTime _lastArabicWarningTime = DateTime.now().subtract(const Duration(seconds: 10));

  OcrService() {
    _initTts();
  }

  Future<void> _initTts() async {
    if (Platform.isIOS) await _flutterTts.setSharedInstance(true);
    await _flutterTts.setLanguage("ar-EG");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
  }

  // =================================================================
  // الوضع 1: الماسح السريع (Google ML Kit) - يعمل مع كاميرا الفيديو
  // =================================================================
  Future<void> processStream(InputImage inputImage) async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      final RecognizedText recognizedText = await _googleRecognizer.processImage(inputImage);
      
      if (recognizedText.blocks.isEmpty) {
        _isBusy = false;
        return;
      }

      String textToSpeak = "";
      List<TextBlock> validBlocks = [];
      
      // فلترة النصوص الصغيرة وتجاهل الضوضاء والخلفيات
      for (TextBlock block in recognizedText.blocks) {
        final Rect box = block.boundingBox;
        double area = box.width * box.height;
        if (area > 3000) { 
          validBlocks.add(block);
        }
      }

      if (validBlocks.isEmpty) {
        _isBusy = false;
        return;
      }

      validBlocks.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

      for (var block in validBlocks) {
        textToSpeak += "${block.text} "; 
      }

      String cleanedText = _cleanText(textToSpeak);

      // الفلتر الهجين الذكي: اكتشاف النص العربي والتنبيه
      if (_containsArabic(cleanedText)) {
        // التحقق من مرور 5 ثواني على الأقل منذ آخر تنبيه لمنع الازعاج
        if (DateTime.now().difference(_lastArabicWarningTime).inSeconds > 5) {
          _lastArabicWarningTime = DateTime.now(); 
          
          // اهتزاز قوي ومختلف للفت الانتباه
          HapticFeedback.heavyImpact(); 
          
          // تحويل اللغة للعربية لنطق التنبيه
          if (_currentLanguage != "ar-EG") {
            _currentLanguage = "ar-EG";
            await _flutterTts.setLanguage("ar-EG");
          }
          
          print("تنبيه: تم اكتشاف نص عربي");
          await _flutterTts.speak("نص عربي"); 
        }
        
        _isBusy = false;
        return; 
      }

      // التحقق من صلاحية النص الانجليزي او الارقام
      if (!_isValidText(cleanedText)) {
        _isBusy = false;
        return;
      }

      // منع التكرار المزعج لنفس النص
      if (cleanedText == _lastReadText && 
          DateTime.now().difference(_lastReadTime).inSeconds < 3) {
        _isBusy = false;
        return;
      }

      // اهتزاز خفيف للنص الانجليزي والارقام
      HapticFeedback.lightImpact(); 
      _textStreamController.add(cleanedText);
      
      _lastReadText = cleanedText;
      _lastReadTime = DateTime.now();

      if (_currentLanguage != "en-US") {
        _currentLanguage = "en-US";
        await _flutterTts.setLanguage("en-US");
      }

      await _flutterTts.speak(cleanedText);

    } catch (e) {
      print("Stream Error: $e");
    } finally {
      _isBusy = false;
    }
  }

  // =================================================================
  // الوضع 2: الماسح العربي (Tesseract) - يعمل بضغطة زر (صورة ثابتة)
  // =================================================================
  Future<void> processArabicImage(String imagePath) async {
    await _flutterTts.stop();
    _isBusy = true; 

    try {
      HapticFeedback.mediumImpact();
      if (_currentLanguage != "ar-EG") {
        _currentLanguage = "ar-EG";
        await _flutterTts.setLanguage("ar-EG");
      }
      
      String text = await FlutterTesseractOcr.extractText(
        imagePath, 
        language: 'ara', 
        args: {
          "psm": "3", // وضع تقسيم الصفحة التلقائي
          "preserve_interword_spaces": "1",
        }
      );

      String cleanedText = text.trim().replaceAll('\n', ' ');
      
      if (cleanedText.length < 3) {
        await _flutterTts.speak("لا يوجد نص واضح");
      } else {
        _textStreamController.add(cleanedText); 
        await _flutterTts.speak(cleanedText);
      }

    } catch (e) {
      print("Tesseract Error: $e");
      await _flutterTts.speak("حدث خطأ في القراءة");
    } finally {
      _isBusy = false; 
    }
  }

  // =================================================================
  // دوال مساعدة للتنظيف والفحص
  // =================================================================
  String _cleanText(String text) {
    String clean = text.replaceAll('\n', ' ').trim();
    clean = clean.replaceAll('|', 'I'); 
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');
    return clean;
  }

  bool _isValidText(String text) {
    if (text.length < 3) return false;
    return RegExp(r'[a-zA-Z0-9]').hasMatch(text);
  }

  bool _containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isBusy = false;
  }

  void dispose() {
    _googleRecognizer.close();
    _flutterTts.stop();
    _textStreamController.close();
  }
}