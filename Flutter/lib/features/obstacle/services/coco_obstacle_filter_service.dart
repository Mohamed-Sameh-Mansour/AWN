import 'dart:math';
import 'dart:ui';

import 'package:myeye/features/obstacle/models/general_object_detection_result.dart';
import 'package:myeye/features/obstacle/models/obstacle_detection_result.dart';
import 'package:myeye/features/obstacle/models/obstacle_label.dart';
import 'package:myeye/features/obstacle/models/obstacle_warning.dart';
import 'package:myeye/features/obstacle/services/obstacle_filter_service.dart';

class CocoObstacleFilterService {
  static const double walkingZoneLeft = 0.24;
  static const double walkingZoneRight = 0.76;
  static const double groundZoneTop = 0.38;

  /// COCO still detects all of its classes, but we only turn useful walking
  /// safety classes into warnings. Everything outside the whitelist is ignored
  /// to keep the app calm and avoid noisy speech from bottles, birds, food,
  /// small devices, signs, and other non-critical objects.
  List<ObstacleDetectionResult> toObstacleDetections(
    List<GeneralObjectDetectionResult> detections,
  ) {
    final results = <ObstacleDetectionResult>[];

    for (final detection in detections) {
      final profile = _profileFor(detection.label);
      if (profile == null) continue;

      final obstacleDetection = _toObstacleDetection(detection, profile);
      if (obstacleDetection.area <= 0) continue;

      results.add(obstacleDetection);
    }

    return results;
  }

  List<ObstacleCandidate> candidatesFrom(
    List<GeneralObjectDetectionResult> detections,
  ) {
    final accepted = <ObstacleCandidate>[];

    for (final detection in detections) {
      final candidate = evaluate(detection);
      if (candidate != null) accepted.add(candidate);
    }

    return accepted;
  }

  ObstacleCandidate? chooseBest(List<GeneralObjectDetectionResult> detections) {
    final accepted = candidatesFrom(detections);

    if (accepted.isEmpty) return null;

    accepted.sort((a, b) {
      final danger = b.dangerScore.compareTo(a.dangerScore);
      if (danger != 0) return danger;

      final priority = b.profile.priority.compareTo(a.profile.priority);
      if (priority != 0) return priority;

      return b.detection.confidence.compareTo(a.detection.confidence);
    });

    return accepted.first;
  }

  ObstacleCandidate? evaluate(GeneralObjectDetectionResult detection) {
    final profile = _profileFor(detection.label);

    if (profile == null) return null;
    if (profile.role == ObstacleClassRole.ignored) return null;
    if (detection.score < profile.minConfidence) return null;
    if (detection.area < profile.minArea) return null;

    final box = Rect.fromLTRB(
      detection.left,
      detection.top,
      detection.right,
      detection.bottom,
    );

    final intersectsWalkingZone = _intersectsWalkingZone(box);

    if (profile.requireWalkingZone && !intersectsWalkingZone) {
      final isVeryClearSideObject =
          detection.score >= profile.minConfidence + 0.22 &&
          detection.area >= profile.minArea * 4.0 &&
          detection.bottom >= 0.78;

      if (!isVeryClearSideObject) return null;
    }

    final probablyRelevant =
        box.center.dy >= groundZoneTop ||
        detection.bottom >= profile.minBottom ||
        detection.area >= profile.minArea * 2.2;

    if (!probablyRelevant) return null;

    final obstacleDetection = _toObstacleDetection(detection, profile);
    final direction = _directionFor(box, intersectsWalkingZone);
    final distance = _distanceFor(detection, profile);
    final dangerScore = _dangerScore(detection, profile, distance, direction);

    return ObstacleCandidate(
      detection: obstacleDetection,
      profile: profile,
      direction: direction,
      distance: distance,
      dangerScore: dangerScore,
      reason: 'coco:${detection.label}',
    );
  }

  ObstacleDetectionResult _toObstacleDetection(
    GeneralObjectDetectionResult detection,
    ObstacleClassProfile profile,
  ) {
    return ObstacleDetectionResult(
      classId: detection.classIndex,
      rawLabel: detection.label,
      label: profile.label,
      confidence: detection.score,
      box: Rect.fromLTRB(
        detection.left,
        detection.top,
        detection.right,
        detection.bottom,
      ),
    );
  }

  bool _intersectsWalkingZone(Rect box) {
    return box.left <= walkingZoneRight && box.right >= walkingZoneLeft;
  }

  ObstacleDirection _directionFor(Rect box, bool intersectsWalkingZone) {
    if (intersectsWalkingZone && box.center.dx > 0.31 && box.center.dx < 0.69) {
      return ObstacleDirection.center;
    }

    if (box.center.dx < 0.40) return ObstacleDirection.left;
    if (box.center.dx > 0.60) return ObstacleDirection.right;

    return ObstacleDirection.center;
  }

  ObstacleDistance _distanceFor(
    GeneralObjectDetectionResult detection,
    ObstacleClassProfile profile,
  ) {
    final area = detection.area;
    final bottom = detection.bottom;

    if (profile.label == ObstacleLabel.vehicle) {
      if (bottom >= 0.90 || area >= 0.22) return ObstacleDistance.veryNear;
      if (bottom >= 0.74 || area >= 0.09) return ObstacleDistance.near;
      if (bottom >= 0.50 || area >= 0.025) return ObstacleDistance.medium;
      return ObstacleDistance.far;
    }

    if (profile.label == ObstacleLabel.person) {
      if (bottom >= 0.92 || area >= 0.26) return ObstacleDistance.veryNear;
      if (bottom >= 0.76 || area >= 0.11) return ObstacleDistance.near;
      if (bottom >= 0.52 || area >= 0.035) return ObstacleDistance.medium;
      return ObstacleDistance.far;
    }

    if (profile.label == ObstacleLabel.animal) {
      if (bottom >= 0.90 || area >= 0.18) return ObstacleDistance.veryNear;
      if (bottom >= 0.72 || area >= 0.070) return ObstacleDistance.near;
      if (bottom >= 0.48 || area >= 0.020) return ObstacleDistance.medium;
      return ObstacleDistance.far;
    }

    if (_isStrictObstacle(profile)) {
      if (bottom >= 0.92 || area >= 0.24) return ObstacleDistance.veryNear;
      if (bottom >= 0.82 || area >= 0.12) return ObstacleDistance.near;
      if (bottom >= 0.68 || area >= 0.055) return ObstacleDistance.medium;
      return ObstacleDistance.far;
    }

    if (bottom >= 0.90 || area >= 0.18) return ObstacleDistance.veryNear;
    if (bottom >= 0.74 || area >= 0.075) return ObstacleDistance.near;
    if (bottom >= 0.50 || area >= 0.024) return ObstacleDistance.medium;

    return ObstacleDistance.far;
  }

  double _dangerScore(
    GeneralObjectDetectionResult detection,
    ObstacleClassProfile profile,
    ObstacleDistance distance,
    ObstacleDirection direction,
  ) {
    final distanceBoost = switch (distance) {
      ObstacleDistance.veryNear => 48.0,
      ObstacleDistance.near => 32.0,
      ObstacleDistance.medium => 15.0,
      ObstacleDistance.far => 0.0,
    };

    final directionBoost = switch (direction) {
      ObstacleDirection.center => 22.0,
      ObstacleDirection.left || ObstacleDirection.right => 5.0,
    };

    final confidenceBoost = detection.score * 30.0;
    final areaBoost = min(24.0, detection.area * 110.0);

    return profile.priority +
        distanceBoost +
        directionBoost +
        confidenceBoost +
        areaBoost;
  }

  ObstacleClassProfile? _profileFor(String label) {
    final cleaned = label.trim().toLowerCase();

    if (cleaned == '???') return null;

    if (_personLabels.contains(cleaned)) {
      return _person();
    }

    if (_vehicleLabels.contains(cleaned)) {
      return _vehicle(priority: _vehiclePriority(cleaned));
    }

    if (_animalLabels.contains(cleaned)) {
      return _animal(priority: _animalPriority(cleaned));
    }

    if (_commonObstacleLabels.contains(cleaned)) {
      return _commonObstacle(priority: _commonObstaclePriority(cleaned));
    }

    if (_portableObstacleLabels.contains(cleaned)) {
      return _portableObstacle(priority: _portableObstaclePriority(cleaned));
    }

    if (_strictObstacleLabels.contains(cleaned)) {
      return _strictObstacle(priority: _strictObstaclePriority(cleaned));
    }

    // Important: no default warning. Ignored COCO classes include bottles,
    // birds, food, cups, books, phones, remotes, signs, and small tools.
    return null;
  }

  ObstacleClassProfile _person() {
    return _profile(
      label: ObstacleLabel.person,
      modelLabel: 'coco:person',
      arabicName: 'شخص',
      priority: 78,
      minConfidence: 0.34,
      minArea: 0.004,
      minBottom: 0.08,
      requireWalkingZone: false,
      stableHits: 2,
    );
  }

  ObstacleClassProfile _vehicle({required int priority}) {
    return _profile(
      label: ObstacleLabel.vehicle,
      modelLabel: 'coco:vehicle',
      arabicName: 'مركبة',
      priority: priority,
      minConfidence: 0.34,
      minArea: 0.006,
      minBottom: 0.08,
      requireWalkingZone: false,
      stableHits: 2,
    );
  }

  ObstacleClassProfile _animal({required int priority}) {
    return _profile(
      label: ObstacleLabel.animal,
      modelLabel: 'coco:animal',
      arabicName: 'حيوان',
      priority: priority,
      minConfidence: 0.36,
      minArea: 0.006,
      minBottom: 0.10,
      requireWalkingZone: false,
      stableHits: 2,
    );
  }

  ObstacleClassProfile _commonObstacle({required int priority}) {
    return _profile(
      label: ObstacleLabel.obstacle,
      modelLabel: 'coco:obstacle',
      arabicName: 'عائق',
      priority: priority,
      minConfidence: 0.32,
      minArea: 0.008,
      minBottom: 0.18,
      requireWalkingZone: true,
      stableHits: 2,
    );
  }

  ObstacleClassProfile _portableObstacle({required int priority}) {
    return _profile(
      label: ObstacleLabel.obstacle,
      modelLabel: 'coco:obstacle',
      arabicName: 'عائق',
      priority: priority,
      minConfidence: 0.40,
      minArea: 0.012,
      minBottom: 0.24,
      requireWalkingZone: true,
      stableHits: 2,
    );
  }

  ObstacleClassProfile _strictObstacle({required int priority}) {
    return _profile(
      label: ObstacleLabel.obstacle,
      modelLabel: 'coco:obstacle',
      arabicName: 'عائق',
      priority: priority,
      minConfidence: 0.52,
      minArea: 0.030,
      minBottom: 0.48,
      requireWalkingZone: true,
      stableHits: 3,
    );
  }

  ObstacleClassProfile _profile({
    required ObstacleLabel label,
    required String modelLabel,
    required String arabicName,
    required int priority,
    required double minConfidence,
    required double minArea,
    required double minBottom,
    required bool requireWalkingZone,
    required int stableHits,
  }) {
    return ObstacleClassProfile(
      label: label,
      modelLabel: modelLabel,
      arabicName: arabicName,
      role: ObstacleClassRole.warning,
      priority: priority,
      minConfidence: minConfidence,
      minArea: minArea,
      minBottom: minBottom,
      groundHazard: false,
      requireWalkingZone: requireWalkingZone,
      stableHits: stableHits,
    );
  }

  bool _isStrictObstacle(ObstacleClassProfile profile) {
    return profile.modelLabel == 'coco:obstacle' && profile.priority <= 62;
  }

  int _vehiclePriority(String label) {
    switch (label) {
      case 'bus':
      case 'truck':
        return 88;
      case 'car':
        return 86;
      case 'motorcycle':
        return 84;
      case 'bicycle':
        return 80;
      case 'train':
        return 78;
      default:
        return 80;
    }
  }

  int _animalPriority(String label) {
    switch (label) {
      case 'dog':
        return 72;
      case 'cat':
        return 66;
      default:
        return 68;
    }
  }

  int _commonObstaclePriority(String label) {
    switch (label) {
      case 'chair':
      case 'couch':
        return 82;
      case 'dining table':
        return 80;
      case 'bed':
        return 78;
      case 'bench':
        return 76;
      case 'potted plant':
        return 72;
      default:
        return 74;
    }
  }

  int _portableObstaclePriority(String label) {
    switch (label) {
      case 'suitcase':
        return 74;
      case 'backpack':
        return 72;
      case 'handbag':
        return 70;
      case 'umbrella':
        return 62;
      default:
        return 68;
    }
  }

  int _strictObstaclePriority(String label) {
    switch (label) {
      case 'fire hydrant':
      case 'parking meter':
        return 70;
      case 'tv':
      case 'laptop':
        return 60;
      default:
        return 58;
    }
  }

  static const Set<String> _personLabels = {
    'person',
  };

  static const Set<String> _vehicleLabels = {
    'bicycle',
    'car',
    'motorcycle',
    'bus',
    'train',
    'truck',
  };

  static const Set<String> _animalLabels = {
    'cat',
    'dog',
    'horse',
    'sheep',
    'cow',
  };

  static const Set<String> _commonObstacleLabels = {
    'bench',
    'chair',
    'couch',
    'bed',
    'dining table',
    'potted plant',
  };

  static const Set<String> _portableObstacleLabels = {
    'backpack',
    'handbag',
    'suitcase',
    'umbrella',
  };

  static const Set<String> _strictObstacleLabels = {
    'fire hydrant',
    'parking meter',
    'tv',
    'laptop',
  };
}
