import 'package:myeye/features/obstacle/models/obstacle_detection_result.dart';
import 'package:myeye/features/obstacle/models/obstacle_label.dart';
import 'package:myeye/features/obstacle/services/obstacle_filter_service.dart';

class CustomSpecialObstacleFilterService {
  CustomSpecialObstacleFilterService({ObstacleFilterService? baseFilter})
    : _baseFilter = baseFilter ?? ObstacleFilterService();

  final ObstacleFilterService _baseFilter;

  static const Set<ObstacleLabel> specialLabels = {
    ObstacleLabel.stairs,
    ObstacleLabel.pothole,
    ObstacleLabel.openedDoor,
  };

  List<ObstacleDetectionResult> visibleDetections(
    List<ObstacleDetectionResult> detections,
  ) {
    return detections.where(_isAcceptedSpecialDetection).toList();
  }

  List<ObstacleCandidate> candidatesFrom(
    List<ObstacleDetectionResult> detections,
  ) {
    final accepted = <ObstacleCandidate>[];

    for (final detection in detections) {
      if (!_isAcceptedSpecialDetection(detection)) continue;

      final candidate = _baseFilter.evaluate(detection);

      if (candidate == null) continue;

      accepted.add(
        ObstacleCandidate(
          detection: candidate.detection,
          profile: candidate.profile,
          direction: candidate.direction,
          distance: candidate.distance,
          dangerScore: candidate.dangerScore + _specialBoost(candidate),
          reason: 'custom-special:${candidate.profile.modelLabel}',
        ),
      );
    }

    return accepted;
  }

  bool _isAcceptedSpecialDetection(ObstacleDetectionResult detection) {
    if (!specialLabels.contains(detection.label)) return false;

    if (detection.confidence < _minConfidenceFor(detection.label)) return false;

    // امنع الومضات الضعيفة جدًا: لازم يكون في ثقة معقولة أو حجم واضح.
    if (detection.confidence < 0.30 && detection.area < 0.012) return false;

    return true;
  }

  double _minConfidenceFor(ObstacleLabel label) {
    switch (label) {
      case ObstacleLabel.stairs:
        return 0.25;
      case ObstacleLabel.pothole:
        return 0.30;
      case ObstacleLabel.openedDoor:
        return 0.25;
      default:
        return 1.0;
    }
  }

  double _specialBoost(ObstacleCandidate candidate) {
    switch (candidate.profile.label) {
      case ObstacleLabel.pothole:
        return 58.0;
      case ObstacleLabel.stairs:
        return 54.0;
      case ObstacleLabel.openedDoor:
        return 48.0;
      default:
        return 0.0;
    }
  }
}
