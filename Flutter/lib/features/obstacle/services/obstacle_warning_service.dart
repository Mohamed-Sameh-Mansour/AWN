import 'package:myeye/features/obstacle/models/obstacle_label.dart';
import 'package:myeye/features/obstacle/models/obstacle_warning.dart';
import 'package:myeye/features/obstacle/services/obstacle_filter_service.dart';

class ObstacleWarningService {
  static const String _vehicleSpeechName = 'مَرْكَبَة';

  DateTime _lastSpeechAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastSignature = '';

  ObstacleWarning buildWarning(ObstacleCandidate candidate) {
    final profile = candidate.profile;
    final directionText = _directionSpeech(candidate.direction);
    final distanceText = _distanceSpeech(candidate.distance);
    final spokenName = _spokenName(profile);

    final isInfo = profile.role == ObstacleClassRole.information;
    final urgent =
        profile.role == ObstacleClassRole.warning &&
        (candidate.distance == ObstacleDistance.near ||
            candidate.distance == ObstacleDistance.veryNear ||
            profile.priority >= 90);

    final speechText = isInfo
        ? _buildInfoSpeech(profile, directionText)
        : _buildWarningSpeech(
            profile: profile,
            spokenName: spokenName,
            directionText: directionText,
            distanceText: distanceText,
          );

    final shortText = isInfo
        ? '$spokenName $directionText'
        : '$spokenName $directionText${distanceText.isEmpty ? '' : ' • $distanceText'}';

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

  bool canSpeak(ObstacleWarning warning) {
    final now = DateTime.now();
    final elapsed = now.difference(_lastSpeechAt).inMilliseconds;

    final same = warning.signature == _lastSignature;
    final minCooldown = same ? 2600 : 1200;

    if (warning.urgent && !same && elapsed >= 700) return true;

    return elapsed >= minCooldown;
  }

  void markSpoken(ObstacleWarning warning) {
    _lastSpeechAt = DateTime.now();
    _lastSignature = warning.signature;
  }

  void reset() {
    _lastSpeechAt = DateTime.fromMillisecondsSinceEpoch(0);
    _lastSignature = '';
  }

  String _buildWarningSpeech({
    required ObstacleClassProfile profile,
    required String spokenName,
    required String directionText,
    required String distanceText,
  }) {
    final distancePart = distanceText.isEmpty ? '' : ' $distanceText';

    switch (profile.label) {
      case ObstacleLabel.pothole:
        return 'تحذير، حفرة $directionText$distancePart.';
      case ObstacleLabel.stairs:
        return 'تحذير، سلم $directionText$distancePart.';
      case ObstacleLabel.openedDoor:
        return 'تحذير، باب $directionText$distancePart.';
      case ObstacleLabel.person:
        return 'انتبه، شخص $directionText$distancePart.';
      case ObstacleLabel.vehicle:
        return 'انتبه، $_vehicleSpeechName $directionText$distancePart.';
      case ObstacleLabel.animal:
        return 'انتبه، حيوان $directionText$distancePart.';
      case ObstacleLabel.obstacle:
        return 'تحذير، عائق $directionText$distancePart.';
      case ObstacleLabel.edgeSidewalk:
        return 'تحذير، حافة رصيف $directionText$distancePart.';
      case ObstacleLabel.poleBollard:
        return 'تحذير، عمود $directionText$distancePart.';
      default:
        return 'تحذير، $spokenName $directionText$distancePart.';
    }
  }

  String _buildInfoSpeech(ObstacleClassProfile profile, String directionText) {
    switch (profile.label) {
      case ObstacleLabel.crosswalk:
        return 'ممر عبور $directionText.';
      case ObstacleLabel.trafficLight:
        return 'إشارة مرور $directionText.';
      default:
        return '${_spokenName(profile)} $directionText.';
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
