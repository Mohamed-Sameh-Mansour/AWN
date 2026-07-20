import 'package:myeye/features/obstacle/models/obstacle_label.dart';
import 'package:myeye/features/obstacle/models/obstacle_warning.dart';
import 'package:myeye/features/obstacle/services/obstacle_filter_service.dart';

class CocoObstacleWarningService {
  static const String _vehicleSpeechName = 'مَرْكَبَة';

  ObstacleWarning buildWarning(ObstacleCandidate candidate) {
    final profile = candidate.profile;
    final directionText = _directionSpeech(candidate.direction);
    final distanceText = _distanceSpeech(candidate.distance);
    final spokenName = _spokenName(profile);

    final urgent =
        candidate.distance == ObstacleDistance.near ||
        candidate.distance == ObstacleDistance.veryNear ||
        profile.priority >= 86;

    final speechText = _buildSpeech(
      profile: profile,
      spokenName: spokenName,
      directionText: directionText,
      distanceText: distanceText,
      urgent: urgent,
    );

    final shortText =
        '$spokenName $directionText${distanceText.isEmpty ? '' : ' • $distanceText'}';

    return ObstacleWarning(
      detection: candidate.detection,
      profile: profile,
      direction: candidate.direction,
      distance: candidate.distance,
      speechText: speechText,
      shortText: shortText,
      urgent: urgent,
    );
  }

  void reset() {}

  String _buildSpeech({
    required ObstacleClassProfile profile,
    required String spokenName,
    required String directionText,
    required String distanceText,
    required bool urgent,
  }) {
    final distancePart = distanceText.isEmpty ? '' : ' $distanceText';

    switch (profile.label) {
      case ObstacleLabel.person:
        return 'انتبه، شخص $directionText$distancePart.';
      case ObstacleLabel.vehicle:
        return 'انتبه، $_vehicleSpeechName $directionText$distancePart.';
      case ObstacleLabel.animal:
        return 'انتبه، حيوان $directionText$distancePart.';
      case ObstacleLabel.obstacle:
        return urgent
            ? 'تحذير، عائق $directionText$distancePart.'
            : 'انتبه، عائق $directionText$distancePart.';
      case ObstacleLabel.openedDoor:
        return 'تحذير، باب $directionText$distancePart.';
      default:
        return urgent
            ? 'تحذير، $spokenName $directionText$distancePart.'
            : 'انتبه، $spokenName $directionText$distancePart.';
    }
  }

  String _spokenName(ObstacleClassProfile profile) {
    switch (profile.label) {
      case ObstacleLabel.person:
        return 'شخص';
      case ObstacleLabel.vehicle:
        return 'مركبة';
      case ObstacleLabel.animal:
        return 'حيوان';
      case ObstacleLabel.obstacle:
        return 'عائق';
      case ObstacleLabel.openedDoor:
        return 'باب';
      case ObstacleLabel.stairs:
        return 'سلم';
      case ObstacleLabel.pothole:
        return 'حفرة';
      case ObstacleLabel.edgeSidewalk:
        return 'حافة رصيف';
      case ObstacleLabel.poleBollard:
        return 'عمود';
      case ObstacleLabel.crosswalk:
        return 'ممر عبور';
      case ObstacleLabel.trafficLight:
        return 'إشارة مرور';
      default:
        return profile.arabicName;
    }
  }

  String _directionSpeech(ObstacleDirection direction) {
    switch (direction) {
      case ObstacleDirection.left:
        return 'على الشمال';
      case ObstacleDirection.center:
        return 'أمامك';
      case ObstacleDirection.right:
        return 'على اليمين';
    }
  }

  String _distanceSpeech(ObstacleDistance distance) {
    switch (distance) {
      case ObstacleDistance.veryNear:
        return 'قريب جدًا';
      case ObstacleDistance.near:
        return 'قريب';
      case ObstacleDistance.medium:
        return 'على مسافة متوسطة';
      case ObstacleDistance.far:
        return '';
    }
  }
}
