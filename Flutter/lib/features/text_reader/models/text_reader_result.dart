class TextReaderResult {
  final String text;
  final String rawText;

  const TextReaderResult({required this.text, this.rawText = ''});

  bool get hasText => text.trim().isNotEmpty;

  factory TextReaderResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'];

    String? formattedText;
    String? rawText;

    if (data is Map<String, dynamic>) {
      formattedText = data['formatted_audio_text']?.toString();
      rawText = data['raw_text']?.toString() ?? data['text']?.toString();

      formattedText ??= data['formattedText']?.toString();
      formattedText ??= data['audio_text']?.toString();
      formattedText ??= data['text']?.toString();
    }

    if (data is List && data.isNotEmpty) {
      final first = data.first;

      if (first is Map<String, dynamic>) {
        formattedText = first['formatted_audio_text']?.toString();
        rawText = first['raw_text']?.toString() ?? first['text']?.toString();

        formattedText ??= first['formattedText']?.toString();
        formattedText ??= first['audio_text']?.toString();
        formattedText ??= first['text']?.toString();
      }

      if (first is String) {
        formattedText = first;
      }
    }

    if (data is String) {
      formattedText = data;
    }

    formattedText ??= json['formatted_audio_text']?.toString();
    formattedText ??= json['formattedText']?.toString();
    formattedText ??= json['audio_text']?.toString();
    formattedText ??= json['text']?.toString();
    formattedText ??= json['message']?.toString();

    return TextReaderResult(
      text: _clean(formattedText ?? ''),
      rawText: _clean(rawText ?? formattedText ?? ''),
    );
  }

  static String _clean(String value) {
    var clean = value.replaceAll('\n', ' ').trim();
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');
    return clean;
  }
}
