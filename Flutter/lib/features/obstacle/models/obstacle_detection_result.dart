import 'dart:ui';

import 'obstacle_label.dart';

class ObstacleDetectionResult {
  final int classId;
  final String rawLabel;
  final ObstacleLabel label;
  final double confidence;

  /// Normalized box from 0.0 to 1.0 after mapping YOLO 640 output.
  final Rect box;

  const ObstacleDetectionResult({
    required this.classId,
    required this.rawLabel,
    required this.label,
    required this.confidence,
    required this.box,
  });

  double get area => box.width * box.height;
  double get bottom => box.bottom;
  double get centerX => box.center.dx;
  double get centerY => box.center.dy;

  ObstacleDetectionResult copyWith({
    int? classId,
    String? rawLabel,
    ObstacleLabel? label,
    double? confidence,
    Rect? box,
  }) {
    return ObstacleDetectionResult(
      classId: classId ?? this.classId,
      rawLabel: rawLabel ?? this.rawLabel,
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
      box: box ?? this.box,
    );
  }
}
