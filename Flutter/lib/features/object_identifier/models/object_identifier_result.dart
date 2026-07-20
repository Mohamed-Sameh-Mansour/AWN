class ObjectIdentifierResult {
  final String objectName;
  final String description;
  final String speechText;
  final double? confidence;

  const ObjectIdentifierResult({
    required this.objectName,
    required this.description,
    required this.speechText,
    this.confidence,
  });

  factory ObjectIdentifierResult.fromApiJson(dynamic json) {
    if (json is String) {
      return ObjectIdentifierResult(
        objectName: '',
        description: json,
        speechText: json,
      );
    }

    if (json is List && json.isNotEmpty) {
      return ObjectIdentifierResult.fromApiJson(json.first);
    }

    if (json is Map<String, dynamic>) {
      final data = json['data'];
      final result = json['result'];
      final predictions = json['predictions'];
      final objects = json['objects'];

      if (data is Map<String, dynamic>) {
        return ObjectIdentifierResult._fromMap({...json, ...data});
      }

      if (data is List && data.isNotEmpty) {
        return ObjectIdentifierResult.fromApiJson(data.first);
      }

      if (data is String) {
        return ObjectIdentifierResult(
          objectName: '',
          description: data,
          speechText: data,
        );
      }

      if (result is Map<String, dynamic>) {
        return ObjectIdentifierResult._fromMap({...json, ...result});
      }

      if (result is List && result.isNotEmpty) {
        return ObjectIdentifierResult.fromApiJson(result.first);
      }

      if (result is String) {
        return ObjectIdentifierResult(
          objectName: '',
          description: result,
          speechText: result,
        );
      }

      if (predictions is List && predictions.isNotEmpty) {
        return ObjectIdentifierResult.fromApiJson(predictions.first);
      }

      if (objects is List && objects.isNotEmpty) {
        return ObjectIdentifierResult.fromApiJson(objects.first);
      }

      return ObjectIdentifierResult._fromMap(json);
    }

    return const ObjectIdentifierResult(
      objectName: '',
      description: '',
      speechText: '',
    );
  }

  factory ObjectIdentifierResult._fromMap(Map<String, dynamic> json) {
    final name = _firstText(json, const [
      'object_name',
      'objectName',
      'object',
      'name',
      'label',
      'class',
      'class_name',
      'detected_object',
      'title',
    ]);

    final description = _firstText(json, const [
      'description',
      'caption',
      'analysis',
      'answer',
      'response',
      'result',
      'text',
      'message',
      'details',
    ]);

    final speech = _firstText(json, const [
      'speech_text',
      'speechText',
      'tts',
      'speak',
      'spoken_text',
      'arabic_response',
    ]);

    final confidence = _firstDouble(json, const [
      'confidence',
      'score',
      'probability',
      'conf',
    ]);

    final cleanName = name.trim();
    final cleanDescription = description.trim();
    final cleanSpeech = speech.trim();

    return ObjectIdentifierResult(
      objectName: cleanName,
      description: cleanDescription,
      speechText: cleanSpeech.isNotEmpty
          ? cleanSpeech
          : _buildDefaultSpeech(
              objectName: cleanName,
              description: cleanDescription,
              confidence: confidence,
            ),
      confidence: confidence,
    );
  }

  static String _firstText(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }

      if (value is num || value is bool) {
        return value.toString();
      }
    }

    return '';
  }

  static double? _firstDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;

      if (value is num) return value.toDouble();

      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }

    return null;
  }

  static String _buildDefaultSpeech({
    required String objectName,
    required String description,
    required double? confidence,
  }) {
    final buffer = StringBuffer();

    if (objectName.trim().isNotEmpty) {
      buffer.write('أعتقد أن أمامك $objectName. ');
    }

    if (description.trim().isNotEmpty) {
      buffer.write(description.trim());
      if (!description.trim().endsWith('.')) {
        buffer.write('.');
      }
      buffer.write(' ');
    }

    if (confidence != null) {
      final percent = confidence <= 1 ? confidence * 100 : confidence;
      buffer.write(
        'نسبة الثقة تقريبًا ${percent.toStringAsFixed(0)} في المية.',
      );
    }

    final text = buffer.toString().trim();
    return text.isEmpty ? 'تم تحليل الصورة، لكن لا يوجد وصف واضح.' : text;
  }

  String get displayTitle {
    if (objectName.trim().isNotEmpty) return objectName.trim();
    return 'تم تحليل الصورة';
  }

  String get displayDescription {
    if (description.trim().isNotEmpty) return description.trim();
    return speechText.trim().isEmpty
        ? 'لا يوجد وصف واضح من السيرفر'
        : speechText.trim();
  }

  String get confidenceText {
    final value = confidence;
    if (value == null) return '';

    final percent = value <= 1 ? value * 100 : value;
    return '${percent.toStringAsFixed(0)}%';
  }

  bool get hasUsefulText {
    return objectName.trim().isNotEmpty ||
        description.trim().isNotEmpty ||
        speechText.trim().isNotEmpty;
  }
}
