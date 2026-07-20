class MedicineDetectionResult {
  final String drugNameAr;
  final String drugNameEn;
  final String description;
  final String pros;
  final String sideEffects;
  final String cons;
  final String dosage;
  final String speechText;
  final double? confidence;

  const MedicineDetectionResult({
    required this.drugNameAr,
    this.drugNameEn = '',
    this.description = '',
    this.pros = '',
    this.sideEffects = '',
    this.cons = '',
    this.dosage = '',
    this.speechText = '',
    this.confidence,
  });

  factory MedicineDetectionResult.fromJson(Map<String, dynamic> json) {
    return MedicineDetectionResult._fromMap(json);
  }

  static List<MedicineDetectionResult> listFromApiJson(dynamic json) {
    if (json == null) return const [];

    if (json is List) {
      return json
          .map(MedicineDetectionResult.fromApiJsonValue)
          .where((result) => result.hasUsefulText)
          .toList();
    }

    if (json is Map<String, dynamic>) {
      final data = json['data'];
      final result = json['result'];
      final results = json['results'];
      final prediction = json['prediction'];
      final predictions = json['predictions'];
      final drugs = json['drugs'];
      final detections = json['detections'];

      final nestedCandidates = [
        data,
        result,
        results,
        prediction,
        predictions,
        drugs,
        detections,
      ];

      for (final candidate in nestedCandidates) {
        final parsed = listFromApiJson(candidate);
        if (parsed.isNotEmpty) return parsed;
      }

      final single = MedicineDetectionResult._fromMap(json);
      return single.hasUsefulText ? [single] : const [];
    }

    if (json is String && json.trim().isNotEmpty) {
      return [
        MedicineDetectionResult(
          drugNameAr: '',
          description: json.trim(),
          speechText: json.trim(),
        ),
      ];
    }

    return const [];
  }

  static MedicineDetectionResult fromApiJsonValue(dynamic json) {
    if (json is Map<String, dynamic>) {
      return MedicineDetectionResult._fromMap(json);
    }

    if (json is String) {
      return MedicineDetectionResult(
        drugNameAr: '',
        description: json.trim(),
        speechText: json.trim(),
      );
    }

    return const MedicineDetectionResult(drugNameAr: '');
  }

  factory MedicineDetectionResult._fromMap(Map<String, dynamic> json) {
    final nameAr = _firstText(json, const [
      'drug_name_ar',
      'drugNameAr',
      'drug_ar',
      'arabic_name',
      'name_ar',
      'medicine_name_ar',
      'detected_drug_ar',
      'drug_name',
      'drugName',
      'medicine_name',
      'medicineName',
      'detected_drug',
      'name',
      'label',
      'class',
      'title',
    ]);

    final nameEn = _firstText(json, const [
      'drug_name_en',
      'drugNameEn',
      'drug_en',
      'english_name',
      'name_en',
      'medicine_name_en',
    ]);

    final description = _firstText(json, const [
      'description',
      'desc',
      'summary',
      'details',
      'detail',
      'analysis',
      'result',
      'response',
      'answer',
      'message',
      'text',
      'arabic_response',
    ]);

    final pros = _firstText(json, const [
      'pros',
      'uses',
      'usage',
      'use',
      'indications',
      'benefits',
      'benefit',
      'purpose',
    ]);

    final sideEffects = _firstText(json, const [
      'side_effects',
      'sideEffects',
      'side_effect',
      'adverse_effects',
      'adverseEffects',
      'effects',
      'risks',
    ]);

    final cons = _firstText(json, const [
      'cons',
      'warnings',
      'warning',
      'contraindications',
      'contraindication',
      'precautions',
      'cautions',
      'avoid',
    ]);

    final dosage = _firstText(json, const [
      'dosage',
      'dose',
      'dosing',
      'recommended_dose',
      'instructions',
    ]);

    final speech = _firstText(json, const [
      'speech_text',
      'speechText',
      'tts',
      'speak',
      'spoken_text',
      'voice_text',
      'audio_text',
    ]);

    final confidence = _firstDouble(json, const [
      'confidence',
      'score',
      'probability',
      'conf',
    ]);

    return MedicineDetectionResult(
      drugNameAr: nameAr.trim(),
      drugNameEn: nameEn.trim(),
      description: description.trim(),
      pros: pros.trim(),
      sideEffects: sideEffects.trim(),
      cons: cons.trim(),
      dosage: dosage.trim(),
      speechText: speech.trim(),
      confidence: confidence,
    );
  }

  static String _firstText(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];

      if (value == null) continue;

      final text = _valueToCleanText(value);

      if (text.isNotEmpty) return text;
    }

    return '';
  }

  static String _valueToCleanText(dynamic value) {
    if (value == null) return '';

    if (value is String) {
      return _cleanText(value);
    }

    if (value is num || value is bool) {
      return value.toString();
    }

    if (value is List) {
      final parts = value
          .map(_valueToCleanText)
          .where((part) => part.trim().isNotEmpty)
          .toList();

      return _cleanText(parts.join('، '));
    }

    if (value is Map) {
      final preferredKeys = const [
        'ar',
        'arabic',
        'text',
        'value',
        'name',
        'description',
        'message',
      ];

      for (final key in preferredKeys) {
        if (value.containsKey(key)) {
          final text = _valueToCleanText(value[key]);
          if (text.isNotEmpty) return text;
        }
      }

      final parts = value.values
          .map(_valueToCleanText)
          .where((part) => part.trim().isNotEmpty)
          .toList();

      return _cleanText(parts.join('، '));
    }

    return _cleanText(value.toString());
  }

  static double? _firstDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];

      if (value == null) continue;

      if (value is num) return value.toDouble();

      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }

    return null;
  }

  static String _cleanText(String text) {
    var clean = text.trim();

    clean = clean.replaceAll(RegExp(r'\s+'), ' ');
    clean = clean.replaceAll('null', '');
    clean = clean.trim();

    return clean;
  }

  String get displayName {
    final ar = drugNameAr.trim();
    if (ar.isNotEmpty) return ar;

    final en = drugNameEn.trim();
    if (en.isNotEmpty) return en;

    return 'دواء غير معروف';
  }

  String get displayDescription {
    if (description.trim().isNotEmpty) return description.trim();
    if (pros.trim().isNotEmpty) return pros.trim();
    if (speechText.trim().isNotEmpty) return speechText.trim();

    return 'تم التعرف على اسم الدواء';
  }

  bool get hasPros => pros.trim().isNotEmpty;
  bool get hasSideEffects => sideEffects.trim().isNotEmpty;
  bool get hasCons => cons.trim().isNotEmpty;
  bool get hasDosage => dosage.trim().isNotEmpty;
  bool get hasDescription => description.trim().isNotEmpty;
  bool get hasSpeechText => speechText.trim().isNotEmpty;

  bool get hasAnyDetails {
    return hasDescription ||
        hasPros ||
        hasSideEffects ||
        hasCons ||
        hasDosage ||
        hasSpeechText;
  }

  bool get hasUsefulText {
    return drugNameAr.trim().isNotEmpty ||
        drugNameEn.trim().isNotEmpty ||
        hasAnyDetails;
  }

  String get confidenceText {
    final value = confidence;
    if (value == null) return '';

    final percent = value <= 1 ? value * 100 : value;
    return '${percent.toStringAsFixed(0)}%';
  }

  String get shortDescription {
    if (hasAnyDetails) {
      return 'تم التعرف على الدواء، ويمكنك الاستماع للتفاصيل';
    }

    return 'تم التعرف على اسم الدواء';
  }

  String buildSpeechText() {
    final buffer = StringBuffer();

    final customSpeech = speechText.trim();

    if (customSpeech.isNotEmpty) {
      buffer.write(_ensureSentence(customSpeech));
      buffer.write(' ');
    } else {
      if (displayName.trim().isNotEmpty) {
        buffer.write('اسم الدواء هو $displayName. ');
      }

      if (drugNameEn.trim().isNotEmpty && drugNameEn.trim() != displayName) {
        buffer.write('واسمه بالإنجليزية $drugNameEn. ');
      }

      if (hasDescription) {
        buffer.write('الوصف: ${description.trim()}. ');
      }

      if (hasPros) {
        buffer.write('الاستخدامات أو الفوائد: ${pros.trim()}. ');
      }

      if (hasDosage) {
        buffer.write('الجرعة أو التعليمات المذكورة: ${dosage.trim()}. ');
      }

      if (hasSideEffects) {
        buffer.write('الأعراض الجانبية المحتملة: ${sideEffects.trim()}. ');
      }

      if (hasCons) {
        buffer.write('التحذيرات أو الموانع: ${cons.trim()}. ');
      }

      if (confidence != null) {
        buffer.write('نسبة الثقة تقريبًا $confidenceText. ');
      }
    }

    buffer.write(
      'تنبيه مهم: هذه معلومات مساعدة فقط، ولا تستخدم الدواء أو تغير الجرعة بدون الرجوع للطبيب أو الصيدلي.',
    );

    return _cleanText(buffer.toString());
  }

  static String _ensureSentence(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return '';

    final endsWithPunctuation = RegExp(r'[.!؟،]$').hasMatch(clean);

    return endsWithPunctuation ? clean : '$clean.';
  }
}
