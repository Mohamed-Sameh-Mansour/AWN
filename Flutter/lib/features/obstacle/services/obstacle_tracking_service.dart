import 'package:myeye/features/obstacle/services/obstacle_filter_service.dart';

class ObstacleTrackingState {
  final int hits;
  final int requiredHits;
  final bool locked;

  const ObstacleTrackingState({
    required this.hits,
    required this.requiredHits,
    required this.locked,
  });
}

class ObstacleTrackingService {
  /// The old system waited for 2-3 stable hits because the previous model
  /// produced more false positives. The hybrid pipeline now uses stronger
  /// confidence/position filters + state-based alert memory, so a valid
  /// candidate is treated as immediately confirmed.
  ObstacleTrackingState update(ObstacleCandidate candidate) {
    return const ObstacleTrackingState(
      hits: 1,
      requiredHits: 1,
      locked: true,
    );
  }

  void reset() {}
}
