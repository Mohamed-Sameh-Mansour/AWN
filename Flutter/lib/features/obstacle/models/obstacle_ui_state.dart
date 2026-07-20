import 'obstacle_detection_result.dart';
import 'obstacle_warning.dart';

class ObstacleUiState {
  final bool canStartCamera;
  final bool scanning;
  final String status;
  final String guide;
  final String label;
  final double confidence;
  final String debug;
  final ObstacleWarning? warning;
  final List<ObstacleDetectionResult> detections;

  const ObstacleUiState({
    required this.canStartCamera,
    required this.scanning,
    required this.status,
    required this.guide,
    required this.label,
    required this.confidence,
    required this.debug,
    required this.warning,
    required this.detections,
  });

  factory ObstacleUiState.initial() {
    return const ObstacleUiState(
      canStartCamera: false,
      scanning: false,
      status: 'جاري التجهيز',
      guide: 'تجهيز كاميرا كشف العوائق',
      label: '—',
      confidence: 0.0,
      debug: 'debug: —',
      warning: null,
      detections: [],
    );
  }

  ObstacleUiState copyWith({
    bool? canStartCamera,
    bool? scanning,
    String? status,
    String? guide,
    String? label,
    double? confidence,
    String? debug,
    ObstacleWarning? warning,
    bool clearWarning = false,
    List<ObstacleDetectionResult>? detections,
  }) {
    return ObstacleUiState(
      canStartCamera: canStartCamera ?? this.canStartCamera,
      scanning: scanning ?? this.scanning,
      status: status ?? this.status,
      guide: guide ?? this.guide,
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
      debug: debug ?? this.debug,
      warning: clearWarning ? null : (warning ?? this.warning),
      detections: detections ?? this.detections,
    );
  }
}
