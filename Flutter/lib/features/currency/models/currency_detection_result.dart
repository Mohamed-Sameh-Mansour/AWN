import 'dart:ui';

class CurrencyDetectionResult {
  final String label;
  final double confidence;
  final Rect boundingBox;

  const CurrencyDetectionResult({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });
}
