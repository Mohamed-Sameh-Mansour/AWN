import 'package:myeye/features/obstacle/models/obstacle_label.dart';
import 'package:myeye/features/obstacle/models/obstacle_warning.dart';
import 'package:myeye/features/obstacle/services/obstacle_filter_service.dart';

class HybridObstacleFusionService {
  const HybridObstacleFusionService();

  ObstacleCandidate? chooseBest({
    required List<ObstacleCandidate> cocoCandidates,
    required List<ObstacleCandidate> customCandidates,
  }) {
    final allCandidates = <ObstacleCandidate>[
      ...cocoCandidates,
      ...customCandidates,
    ];

    if (allCandidates.isEmpty) return null;

    final strongCustomSpecial = _strongestCustomSpecial(customCandidates);

    if (strongCustomSpecial != null) {
      return strongCustomSpecial;
    }

    allCandidates.sort((a, b) {
      final danger = b.dangerScore.compareTo(a.dangerScore);
      if (danger != 0) return danger;

      final priority = b.profile.priority.compareTo(a.profile.priority);
      if (priority != 0) return priority;

      return b.detection.confidence.compareTo(a.detection.confidence);
    });

    return allCandidates.first;
  }

  ObstacleCandidate? _strongestCustomSpecial(
    List<ObstacleCandidate> customCandidates,
  ) {
    final specials = customCandidates.where(_isSpecialCustomCandidate).toList();

    if (specials.isEmpty) return null;

    specials.sort((a, b) {
      final danger = b.dangerScore.compareTo(a.dangerScore);
      if (danger != 0) return danger;

      final priority = b.profile.priority.compareTo(a.profile.priority);
      if (priority != 0) return priority;

      return b.detection.confidence.compareTo(a.detection.confidence);
    });

    final best = specials.first;

    final confidentEnough = best.detection.confidence >= 0.25;
    final visibleEnough = best.detection.area >= 0.012;
    final notFar = best.distance != ObstacleDistance.far;

    if (confidentEnough && (visibleEnough || notFar)) {
      return best;
    }

    return null;
  }

  bool _isSpecialCustomCandidate(ObstacleCandidate candidate) {
    if (!candidate.reason.startsWith('custom-special:')) return false;

    return candidate.profile.label == ObstacleLabel.stairs ||
        candidate.profile.label == ObstacleLabel.pothole ||
        candidate.profile.label == ObstacleLabel.openedDoor;
  }

}
