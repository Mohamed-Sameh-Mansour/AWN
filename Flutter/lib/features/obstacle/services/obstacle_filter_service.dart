import 'dart:math';

import 'package:flutter/widgets.dart';

import 'package:myeye/features/obstacle/models/obstacle_detection_result.dart';
import 'package:myeye/features/obstacle/models/obstacle_label.dart';
import 'package:myeye/features/obstacle/models/obstacle_warning.dart';

class ObstacleCandidate {
  final ObstacleDetectionResult detection;
  final ObstacleClassProfile profile;
  final ObstacleDirection direction;
  final ObstacleDistance distance;
  final double dangerScore;
  final String reason;

  const ObstacleCandidate({
    required this.detection,
    required this.profile,
    required this.direction,
    required this.distance,
    required this.dangerScore,
    required this.reason,
  });
}

class ObstacleFilterService {
  static const double minimumAcceptedConfidence = 0.22;

  static const double walkingZoneLeft = 0.24;
  static const double walkingZoneRight = 0.76;
  static const double groundZoneTop = 0.38;

  ObstacleCandidate? chooseBest(List<ObstacleDetectionResult> detections) {
    final accepted = <ObstacleCandidate>[];

    for (final detection in detections) {
      final candidate = evaluate(detection);
      if (candidate != null) accepted.add(candidate);
    }

    if (accepted.isEmpty) return null;

    accepted.sort((a, b) {
      if (a.profile.role != b.profile.role) {
        if (a.profile.role == ObstacleClassRole.warning) return -1;
        if (b.profile.role == ObstacleClassRole.warning) return 1;
      }

      final danger = b.dangerScore.compareTo(a.dangerScore);
      if (danger != 0) return danger;

      final priority = b.profile.priority.compareTo(a.profile.priority);
      if (priority != 0) return priority;

      return b.detection.confidence.compareTo(a.detection.confidence);
    });

    return accepted.first;
  }

  ObstacleCandidate? evaluate(ObstacleDetectionResult detection) {
    final profile = ObstacleClassProfiles.profileOf(detection.label);
    final box = detection.box;

    if (profile.role == ObstacleClassRole.ignored) return null;

    final effectiveMinConfidence = max(
      minimumAcceptedConfidence,
      profile.minConfidence,
    );

    if (detection.confidence < effectiveMinConfidence) return null;

    if (detection.area < profile.minArea) return null;

    final tooTinyAndWeak =
        detection.confidence < 0.15 && detection.area < 0.002;
    if (tooTinyAndWeak) return null;

    final intersectsWalkingZone = _intersectsWalkingZone(box);

    if (profile.requireWalkingZone && !intersectsWalkingZone) {
      final isStrongEnoughToKeep =
          detection.confidence >= max(0.32, minimumAcceptedConfidence);

      if (!isStrongEnoughToKeep) return null;
    }

    if (profile.groundHazard) {
      final requiredCenterY = profile.label == ObstacleLabel.stairs ? 0.30 : groundZoneTop;
      final requiredBottom = profile.label == ObstacleLabel.stairs ? 0.36 : 0.42;

      final probablyOnGround =
          box.center.dy >= requiredCenterY || detection.bottom >= requiredBottom;

      if (!probablyOnGround) return null;
    }

    final direction = _directionFor(box, intersectsWalkingZone);
    final distance = _distanceFor(detection, profile);
    final dangerScore = _dangerScore(detection, profile, distance, direction);

    return ObstacleCandidate(
      detection: detection,
      profile: profile,
      direction: direction,
      distance: distance,
      dangerScore: dangerScore,
      reason: 'accepted',
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
    ObstacleDetectionResult detection,
    ObstacleClassProfile profile,
  ) {
    final area = detection.area;
    final bottom = detection.bottom;

    if (profile.groundHazard) {
      if (bottom >= 0.88 || area >= 0.13) return ObstacleDistance.veryNear;
      if (bottom >= 0.72 || area >= 0.055) return ObstacleDistance.near;
      if (bottom >= 0.52 || area >= 0.015) return ObstacleDistance.medium;
      return ObstacleDistance.far;
    }

    if (bottom >= 0.90 || area >= 0.21) return ObstacleDistance.veryNear;
    if (bottom >= 0.73 || area >= 0.080) return ObstacleDistance.near;
    if (bottom >= 0.48 || area >= 0.020) return ObstacleDistance.medium;
    return ObstacleDistance.far;
  }

  double _dangerScore(
    ObstacleDetectionResult detection,
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

    final roleBoost = switch (profile.role) {
      ObstacleClassRole.warning => 20.0,
      ObstacleClassRole.information => 0.0,
      ObstacleClassRole.ignored => -999.0,
    };

    final confidenceBoost = detection.confidence * 28.0;
    final areaBoost = min(22.0, detection.area * 105.0);

    return roleBoost +
        profile.priority +
        distanceBoost +
        directionBoost +
        confidenceBoost +
        areaBoost;
  }
}
