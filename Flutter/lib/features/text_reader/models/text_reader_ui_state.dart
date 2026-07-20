enum TextReaderMode { english, arabic }

class TextReaderUiState {
  final TextReaderMode mode;

  final String statusText;
  final String titleText;
  final String subtitleText;
  final String recognizedText;

  final bool isCameraAllowed;
  final bool isBusy;
  final bool isTorchOn;
  final bool hasResult;

  const TextReaderUiState({
    required this.mode,
    required this.statusText,
    required this.titleText,
    required this.subtitleText,
    required this.recognizedText,
    required this.isCameraAllowed,
    required this.isBusy,
    required this.isTorchOn,
    required this.hasResult,
  });

  factory TextReaderUiState.initial() {
    return const TextReaderUiState(
      mode: TextReaderMode.arabic,
      statusText: 'جاري تجهيز قارئ النصوص',
      titleText: 'قارئ النصوص',
      subtitleText: 'قل تصوير لقراءة النص. قل إغلاق للخروج.',
      recognizedText: '',
      isCameraAllowed: false,
      isBusy: true,
      isTorchOn: false,
      hasResult: false,
    );
  }

  bool get isCaptureEnabled => isCameraAllowed && !isBusy;

  bool get isListenEnabled =>
      hasResult && recognizedText.trim().isNotEmpty && !isBusy;

  String get modeLabel {
    switch (mode) {
      case TextReaderMode.english:
        return 'English Offline OCR';
      case TextReaderMode.arabic:
        return 'Server OCR';
    }
  }

  TextReaderUiState copyWith({
    TextReaderMode? mode,
    String? statusText,
    String? titleText,
    String? subtitleText,
    String? recognizedText,
    bool clearRecognizedText = false,
    bool? isCameraAllowed,
    bool? isBusy,
    bool? isTorchOn,
    bool? hasResult,
  }) {
    return TextReaderUiState(
      mode: mode ?? this.mode,
      statusText: statusText ?? this.statusText,
      titleText: titleText ?? this.titleText,
      subtitleText: subtitleText ?? this.subtitleText,
      recognizedText: clearRecognizedText
          ? ''
          : (recognizedText ?? this.recognizedText),
      isCameraAllowed: isCameraAllowed ?? this.isCameraAllowed,
      isBusy: isBusy ?? this.isBusy,
      isTorchOn: isTorchOn ?? this.isTorchOn,
      hasResult: hasResult ?? this.hasResult,
    );
  }
}
