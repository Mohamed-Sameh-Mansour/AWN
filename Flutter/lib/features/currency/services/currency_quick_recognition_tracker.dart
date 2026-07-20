import 'package:myeye/core/constants/app_constants.dart';

class CurrencyQuickRecognitionResult {
  final bool shouldAnnounce;
  final String label;
  final double confidence;

  const CurrencyQuickRecognitionResult.ignore()
    : shouldAnnounce = false,
      label = '',
      confidence = 0.0;

  const CurrencyQuickRecognitionResult.announce({
    required this.label,
    required this.confidence,
  }) : shouldAnnounce = true;
}

class CurrencyQuickRecognitionTracker {
  String _lastLabel = '';
  int _consecutiveHits = 0;
  double _bestConfidence = 0.0;
  DateTime _lastSeenAt = DateTime.fromMillisecondsSinceEpoch(0);

  void reset() {
    _lastLabel = '';
    _consecutiveHits = 0;
    _bestConfidence = 0.0;
    _lastSeenAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  CurrencyQuickRecognitionResult update({
    required String label,
    required double confidence,
  }) {
    final now = DateTime.now();

    final timeSinceLastFrame = now.difference(_lastSeenAt).inMilliseconds;

    final memoryExpired =
        timeSinceLastFrame > CurrencyConstants.quickMemoryWindowMs;

    if (memoryExpired) {
      reset();
    }

    if (confidence < CurrencyConstants.minConfidenceForQuickAnnounce) {
      reset();
      return const CurrencyQuickRecognitionResult.ignore();
    }

    if (_lastLabel == label && !memoryExpired) {
      _consecutiveHits++;

      if (confidence > _bestConfidence) {
        _bestConfidence = confidence;
      }
    } else {
      _lastLabel = label;
      _consecutiveHits = 1;
      _bestConfidence = confidence;
    }

    _lastSeenAt = now;

    if (_consecutiveHits < CurrencyConstants.quickHitsToAnnounce) {
      return const CurrencyQuickRecognitionResult.ignore();
    }

    return CurrencyQuickRecognitionResult.announce(
      label: _lastLabel,
      confidence: _bestConfidence,
    );
  }
}
