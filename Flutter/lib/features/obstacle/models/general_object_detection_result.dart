class GeneralObjectDetectionResult {
  const GeneralObjectDetectionResult({
    required this.classIndex,
    required this.label,
    required this.score,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int classIndex;
  final String label;
  final double score;

  /// Normalized box coordinates from 0.0 to 1.0.
  /// left/top/right/bottom are relative to the camera frame size.
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => (right - left).clamp(0.0, 1.0);

  double get height => (bottom - top).clamp(0.0, 1.0);

  double get area => width * height;

  double get centerX => ((left + right) / 2).clamp(0.0, 1.0);

  double get centerY => ((top + bottom) / 2).clamp(0.0, 1.0);

  bool get hasValidBox {
    return left >= 0.0 &&
        top >= 0.0 &&
        right <= 1.0 &&
        bottom <= 1.0 &&
        right > left &&
        bottom > top;
  }

  /// These are common COCO objects that can matter for walking safety.
  /// We will use this later when we merge COCO with the obstacle detector.
  bool get isPotentialObstacle {
    return _potentialObstacleLabels.contains(label.toLowerCase().trim());
  }

  /// Middle area of the frame where a blind user is more likely walking toward.
  /// This is only a helper. The real risk logic will be handled later.
  bool get isInsideWalkingZone {
    return centerX >= 0.22 && centerX <= 0.78 && bottom >= 0.38;
  }

  /// Bigger bounding box usually means closer object.
  /// This is relative proximity, not real-world distance.
  bool get looksClose {
    return area >= 0.10 || height >= 0.42 || bottom >= 0.82;
  }

  GeneralObjectDetectionResult copyWith({
    int? classIndex,
    String? label,
    double? score,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    return GeneralObjectDetectionResult(
      classIndex: classIndex ?? this.classIndex,
      label: label ?? this.label,
      score: score ?? this.score,
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
    );
  }

  @override
  String toString() {
    final percent = (score * 100).toStringAsFixed(1);
    final box =
        'left=${left.toStringAsFixed(2)}, '
        'top=${top.toStringAsFixed(2)}, '
        'right=${right.toStringAsFixed(2)}, '
        'bottom=${bottom.toStringAsFixed(2)}';

    return 'GeneralObjectDetectionResult('
        'label=$label, '
        'score=$percent%, '
        'classIndex=$classIndex, '
        '$box'
        ')';
  }

  static const Set<String> _potentialObstacleLabels = {
    'person',
    'bicycle',
    'car',
    'motorcycle',
    'bus',
    'train',
    'truck',
    'cat',
    'dog',
    'horse',
    'sheep',
    'cow',
    'bench',
    'chair',
    'couch',
    'bed',
    'dining table',
    'potted plant',
    'backpack',
    'handbag',
    'suitcase',
    'umbrella',
    'fire hydrant',
    'parking meter',
    'tv',
    'laptop',
  };
}
