import 'medicine_detection_result.dart';

class MedicineUiState {
  final String statusText;
  final String titleText;
  final String subtitleText;
  final String actionText;

  final bool isCameraAllowed;
  final bool isBusy;
  final bool hasResult;
  final bool isTorchOn;
  final bool isAutoFlashEnabled;

  final MedicineDetectionResult? result;

  const MedicineUiState({
    required this.statusText,
    required this.titleText,
    required this.subtitleText,
    required this.actionText,
    required this.isCameraAllowed,
    required this.isBusy,
    required this.hasResult,
    required this.isTorchOn,
    required this.isAutoFlashEnabled,
    required this.result,
  });

  factory MedicineUiState.initial() {
    return const MedicineUiState(
      statusText: 'جاري تجهيز الكاميرا...',
      titleText: 'بانتظار تحديد الدواء',
      subtitleText: 'وجّه علبة الدواء داخل الإطار ثم اضغط للتصوير',
      actionText: 'استمع للتفاصيل',
      isCameraAllowed: false,
      isBusy: false,
      hasResult: false,
      isTorchOn: false,
      isAutoFlashEnabled: true,
      result: null,
    );
  }

  bool get isCaptureEnabled => isCameraAllowed && !isBusy;
  bool get isListenEnabled => hasResult && result != null && !isBusy;

  MedicineUiState copyWith({
    String? statusText,
    String? titleText,
    String? subtitleText,
    String? actionText,
    bool? isCameraAllowed,
    bool? isBusy,
    bool? hasResult,
    bool? isTorchOn,
    bool? isAutoFlashEnabled,
    MedicineDetectionResult? result,
    bool clearResult = false,
  }) {
    return MedicineUiState(
      statusText: statusText ?? this.statusText,
      titleText: titleText ?? this.titleText,
      subtitleText: subtitleText ?? this.subtitleText,
      actionText: actionText ?? this.actionText,
      isCameraAllowed: isCameraAllowed ?? this.isCameraAllowed,
      isBusy: isBusy ?? this.isBusy,
      hasResult: hasResult ?? this.hasResult,
      isTorchOn: isTorchOn ?? this.isTorchOn,
      isAutoFlashEnabled: isAutoFlashEnabled ?? this.isAutoFlashEnabled,
      result: clearResult ? null : (result ?? this.result),
    );
  }
}
