import 'object_identifier_result.dart';

class ObjectIdentifierUiState {
  final String statusText;
  final String titleText;
  final String subtitleText;
  final String actionText;

  final bool isCameraAllowed;
  final bool isBusy;
  final bool hasResult;

  final ObjectIdentifierResult? result;

  const ObjectIdentifierUiState({
    required this.statusText,
    required this.titleText,
    required this.subtitleText,
    required this.actionText,
    required this.isCameraAllowed,
    required this.isBusy,
    required this.hasResult,
    required this.result,
  });

  factory ObjectIdentifierUiState.initial() {
    return const ObjectIdentifierUiState(
      statusText: 'جاري تجهيز الكاميرا...',
      titleText: 'تجربة معرفة الأشياء',
      subtitleText: 'وجّه الكاميرا نحو الشيء ثم اضغط مرتين للتصوير',
      actionText: 'استمع مرة أخرى',
      isCameraAllowed: false,
      isBusy: false,
      hasResult: false,
      result: null,
    );
  }

  bool get isCaptureEnabled => isCameraAllowed && !isBusy;

  bool get isListenEnabled => hasResult && result != null && !isBusy;

  ObjectIdentifierUiState copyWith({
    String? statusText,
    String? titleText,
    String? subtitleText,
    String? actionText,
    bool? isCameraAllowed,
    bool? isBusy,
    bool? hasResult,
    ObjectIdentifierResult? result,
    bool clearResult = false,
  }) {
    return ObjectIdentifierUiState(
      statusText: statusText ?? this.statusText,
      titleText: titleText ?? this.titleText,
      subtitleText: subtitleText ?? this.subtitleText,
      actionText: actionText ?? this.actionText,
      isCameraAllowed: isCameraAllowed ?? this.isCameraAllowed,
      isBusy: isBusy ?? this.isBusy,
      hasResult: hasResult ?? this.hasResult,
      result: clearResult ? null : (result ?? this.result),
    );
  }
}
