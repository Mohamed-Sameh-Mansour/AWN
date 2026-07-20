import 'obstacle_detection_result.dart';
import 'obstacle_label.dart';

enum ObstacleDirection { left, center, right }
enum ObstacleDistance { far, medium, near, veryNear }

class ObstacleWarning {
  final ObstacleDetectionResult detection;
  final ObstacleClassProfile profile;
  final ObstacleDirection direction;
  final ObstacleDistance distance;
  final String speechText;
  final String shortText;
  final bool urgent;

  const ObstacleWarning({
    required this.detection,
    required this.profile,
    required this.direction,
    required this.distance,
    required this.speechText,
    required this.shortText,
    required this.urgent,
  });

  String get signature =>
      '${profile.label.name}|${profile.modelLabel}|${direction.name}|${distance.name}';
}
