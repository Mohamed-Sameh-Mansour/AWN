enum ObstacleLabel {
  crosswalk,
  edgeSidewalk,
  openedDoor,
  trafficLight,
  obstacle,
  vehicle,
  person,
  poleBollard,
  pothole,
  stairs,
  animal,
  cane,
  unknown,
}

enum ObstacleClassRole { warning, information, ignored }

class ObstacleClassProfile {
  final ObstacleLabel label;
  final String modelLabel;
  final String arabicName;
  final ObstacleClassRole role;
  final int priority;
  final double minConfidence;
  final double minArea;
  final double minBottom;
  final bool groundHazard;
  final bool requireWalkingZone;
  final int stableHits;

  const ObstacleClassProfile({
    required this.label,
    required this.modelLabel,
    required this.arabicName,
    required this.role,
    required this.priority,
    required this.minConfidence,
    required this.minArea,
    required this.minBottom,
    required this.groundHazard,
    required this.requireWalkingZone,
    required this.stableHits,
  });
}

class ObstacleClassProfiles {
  const ObstacleClassProfiles._();

  static const double warningConfidence = 0.22;
  static const double informationConfidence = 0.40;

  static const Map<ObstacleLabel, ObstacleClassProfile> byLabel = {
    ObstacleLabel.crosswalk: ObstacleClassProfile(
      label: ObstacleLabel.crosswalk,
      modelLabel: 'Crosswalk',
      arabicName: 'ممر عبور',
      role: ObstacleClassRole.information,
      priority: 20,
      minConfidence: informationConfidence,
      minArea: 0.001,
      minBottom: 0.10,
      groundHazard: true,
      requireWalkingZone: true,
      stableHits: 2,
    ),
    ObstacleLabel.edgeSidewalk: ObstacleClassProfile(
      label: ObstacleLabel.edgeSidewalk,
      modelLabel: 'Edge_Sidewalk',
      arabicName: 'حافة رصيف',
      role: ObstacleClassRole.warning,
      priority: 74,
      minConfidence: warningConfidence,
      minArea: 0.001,
      minBottom: 0.20,
      groundHazard: true,
      requireWalkingZone: true,
      stableHits: 2,
    ),
    ObstacleLabel.openedDoor: ObstacleClassProfile(
      label: ObstacleLabel.openedDoor,
      modelLabel: 'Opened_Door',
      arabicName: 'باب',
      role: ObstacleClassRole.warning,
      priority: 94,
      minConfidence: warningConfidence,
      minArea: 0.001,
      minBottom: 0.08,
      groundHazard: false,
      requireWalkingZone: false,
      stableHits: 1,
    ),
    ObstacleLabel.trafficLight: ObstacleClassProfile(
      label: ObstacleLabel.trafficLight,
      modelLabel: 'Traffic_Light',
      arabicName: 'إشارة مرور',
      role: ObstacleClassRole.information,
      priority: 18,
      minConfidence: informationConfidence,
      minArea: 0.001,
      minBottom: 0.02,
      groundHazard: false,
      requireWalkingZone: false,
      stableHits: 2,
    ),
    ObstacleLabel.obstacle: ObstacleClassProfile(
      label: ObstacleLabel.obstacle,
      modelLabel: 'Obstacle',
      arabicName: 'عائق',
      role: ObstacleClassRole.warning,
      priority: 80,
      minConfidence: warningConfidence,
      minArea: 0.001,
      minBottom: 0.10,
      groundHazard: false,
      requireWalkingZone: true,
      stableHits: 2,
    ),
    ObstacleLabel.vehicle: ObstacleClassProfile(
      label: ObstacleLabel.vehicle,
      modelLabel: 'Vehicle',
      arabicName: 'مركبة',
      role: ObstacleClassRole.warning,
      priority: 84,
      minConfidence: warningConfidence,
      minArea: 0.001,
      minBottom: 0.08,
      groundHazard: false,
      requireWalkingZone: false,
      stableHits: 2,
    ),
    ObstacleLabel.person: ObstacleClassProfile(
      label: ObstacleLabel.person,
      modelLabel: 'Person',
      arabicName: 'شخص',
      role: ObstacleClassRole.warning,
      priority: 78,
      minConfidence: warningConfidence,
      minArea: 0.001,
      minBottom: 0.08,
      groundHazard: false,
      requireWalkingZone: false,
      stableHits: 2,
    ),
    ObstacleLabel.poleBollard: ObstacleClassProfile(
      label: ObstacleLabel.poleBollard,
      modelLabel: 'Pole_Bollard',
      arabicName: 'عمود',
      role: ObstacleClassRole.warning,
      priority: 82,
      minConfidence: warningConfidence,
      minArea: 0.001,
      minBottom: 0.10,
      groundHazard: false,
      requireWalkingZone: true,
      stableHits: 2,
    ),
    ObstacleLabel.pothole: ObstacleClassProfile(
      label: ObstacleLabel.pothole,
      modelLabel: 'Pothole',
      arabicName: 'حفرة',
      role: ObstacleClassRole.warning,
      priority: 98,
      minConfidence: warningConfidence,
      minArea: 0.001,
      minBottom: 0.16,
      groundHazard: true,
      requireWalkingZone: true,
      stableHits: 1,
    ),
    ObstacleLabel.stairs: ObstacleClassProfile(
      label: ObstacleLabel.stairs,
      modelLabel: 'Stairs',
      arabicName: 'سلم',
      role: ObstacleClassRole.warning,
      priority: 97,
      minConfidence: warningConfidence,
      minArea: 0.001,
      minBottom: 0.14,
      groundHazard: true,
      requireWalkingZone: false,
      stableHits: 1,
    ),
    ObstacleLabel.animal: ObstacleClassProfile(
      label: ObstacleLabel.animal,
      modelLabel: 'Animal',
      arabicName: 'حيوان',
      role: ObstacleClassRole.warning,
      priority: 72,
      minConfidence: warningConfidence,
      minArea: 0.001,
      minBottom: 0.08,
      groundHazard: false,
      requireWalkingZone: false,
      stableHits: 2,
    ),
    ObstacleLabel.cane: ObstacleClassProfile(
      label: ObstacleLabel.cane,
      modelLabel: 'Cane',
      arabicName: 'عصا',
      role: ObstacleClassRole.ignored,
      priority: 1,
      minConfidence: 0.90,
      minArea: 0.004,
      minBottom: 0.25,
      groundHazard: false,
      requireWalkingZone: false,
      stableHits: 99,
    ),
    ObstacleLabel.unknown: ObstacleClassProfile(
      label: ObstacleLabel.unknown,
      modelLabel: 'Unknown',
      arabicName: 'غير معروف',
      role: ObstacleClassRole.ignored,
      priority: 0,
      minConfidence: 0.95,
      minArea: 1.0,
      minBottom: 1.0,
      groundHazard: false,
      requireWalkingZone: false,
      stableHits: 99,
    ),
  };

  static ObstacleClassProfile profileOf(ObstacleLabel label) {
    return byLabel[label] ?? byLabel[ObstacleLabel.unknown]!;
  }

  static ObstacleLabel fromModelLabel(String value) {
    final cleaned = value.trim().toLowerCase().replaceAll('-', '_');

    switch (cleaned) {
      case 'crosswalk':
        return ObstacleLabel.crosswalk;
      case 'edge_sidewalk':
        return ObstacleLabel.edgeSidewalk;
      case 'opened_door':
        return ObstacleLabel.openedDoor;
      case 'traffic_light':
        return ObstacleLabel.trafficLight;
      case 'obstacle':
        return ObstacleLabel.obstacle;
      case 'vehicle':
        return ObstacleLabel.vehicle;
      case 'person':
        return ObstacleLabel.person;
      case 'pole_bollard':
        return ObstacleLabel.poleBollard;
      case 'pothole':
        return ObstacleLabel.pothole;
      case 'stairs':
        return ObstacleLabel.stairs;
      case 'animal':
        return ObstacleLabel.animal;
      case 'cane':
        return ObstacleLabel.cane;
      default:
        return ObstacleLabel.unknown;
    }
  }
}
