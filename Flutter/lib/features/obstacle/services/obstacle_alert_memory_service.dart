import 'dart:math';

import 'package:myeye/features/obstacle/models/obstacle_warning.dart';
import 'package:myeye/features/obstacle/services/obstacle_filter_service.dart';
import 'package:myeye/features/obstacle/services/obstacle_tracking_service.dart';

class ObstacleAlertDecision {
  final bool shouldSpeak;
  final bool shouldVibrate;
  final String reason;

  const ObstacleAlertDecision({
    required this.shouldSpeak,
    required this.shouldVibrate,
    required this.reason,
  });

  const ObstacleAlertDecision.silent(this.reason)
      : shouldSpeak = false,
        shouldVibrate = false;

  const ObstacleAlertDecision.speak({
    required this.reason,
    required this.shouldVibrate,
  }) : shouldSpeak = true;
}

class ObstacleAlertMemoryService {
  /// Small global gaps only prevent voice overlap when the scene changes fast.
  /// They are not periodic repeat timers.
  static const int globalNormalGapMs = 650;
  static const int globalUrgentGapMs = 300;

  /// If the same situation stays visible, repeat the warning after this time.
  /// This prevents constant repetition while still reminding the user if the
  /// obstacle remains in front of them for a while.
  static const int repeatSameSituationAfterMs = 5000;

  /// If no candidate appears for this time, the old spoken situation is cleared.
  /// This allows the same class to be announced again after it truly disappears
  /// and comes back.
  static const int clearAfterNoCandidateMs = 1400;

  final Map<String, _LabelAlertMemory> _labelMemory = {};

  DateTime _lastAnySpeechAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastCandidateAt = DateTime.fromMillisecondsSinceEpoch(0);

  ObstacleAlertDecision updateAndDecide({
    required ObstacleCandidate candidate,
    required ObstacleTrackingState trackState,
    required ObstacleWarning warning,
  }) {
    final now = DateTime.now();

    _lastCandidateAt = now;

    if (!trackState.locked) {
      return ObstacleAlertDecision.silent(
        'waiting-stability:${trackState.hits}/${trackState.requiredHits}',
      );
    }

    final memoryKey = _memoryKey(candidate);
    final memory = _labelMemory.putIfAbsent(
      memoryKey,
      () => _LabelAlertMemory(),
    );

    final globalElapsed = now.difference(_lastAnySpeechAt).inMilliseconds;
    final globalGap = warning.urgent ? globalUrgentGapMs : globalNormalGapMs;

    final firstTimeForThisSituation = memory.lastSpokenAt == null;

    final distanceEscalated =
        memory.lastDistance != null &&
        _distanceRank(candidate.distance) > _distanceRank(memory.lastDistance!);

    final movedIntoCenter =
        memory.lastDirection != null &&
        memory.lastDirection != ObstacleDirection.center &&
        candidate.direction == ObstacleDirection.center;

    final directionChangedStrongly =
        memory.lastDirection != null &&
        memory.lastDirection != candidate.direction &&
        candidate.direction == ObstacleDirection.center;

    final becameUrgent = !memory.lastUrgent && warning.urgent;

    final confidenceJump =
        memory.lastConfidence != null &&
        candidate.detection.confidence >= memory.lastConfidence! + 0.20;

    final priorityJump =
        memory.lastPriority != null &&
        candidate.profile.priority >= memory.lastPriority! + 12;

    final biggerAndCloser =
        memory.lastArea != null &&
        memory.lastBottom != null &&
        candidate.detection.area >= memory.lastArea! * 1.70 &&
        candidate.detection.bottom >= memory.lastBottom! + 0.08;

    final importantChange =
        distanceEscalated ||
        movedIntoCenter ||
        directionChangedStrongly ||
        becameUrgent ||
        confidenceJump ||
        priorityJump ||
        biggerAndCloser;

    if (firstTimeForThisSituation && globalElapsed >= globalGap) {
      _markSpoken(
        now: now,
        memory: memory,
        candidate: candidate,
        warning: warning,
      );

      return ObstacleAlertDecision.speak(
        reason: 'first-seen-${candidate.profile.modelLabel}',
        shouldVibrate: warning.urgent,
      );
    }

    if (importantChange && globalElapsed >= globalUrgentGapMs) {
      _markSpoken(
        now: now,
        memory: memory,
        candidate: candidate,
        warning: warning,
      );

      return ObstacleAlertDecision.speak(
        reason: _changeReason(
          distanceEscalated: distanceEscalated,
          movedIntoCenter: movedIntoCenter,
          directionChangedStrongly: directionChangedStrongly,
          becameUrgent: becameUrgent,
          confidenceJump: confidenceJump,
          priorityJump: priorityJump,
          biggerAndCloser: biggerAndCloser,
        ),
        shouldVibrate: warning.urgent || distanceEscalated || movedIntoCenter,
      );
    }

    final sameSituationExpired =
        memory.lastSpokenAt != null &&
        now.difference(memory.lastSpokenAt!).inMilliseconds >=
            repeatSameSituationAfterMs;

    if (sameSituationExpired && globalElapsed >= globalGap) {
      _markSpoken(
        now: now,
        memory: memory,
        candidate: candidate,
        warning: warning,
      );

      return ObstacleAlertDecision.speak(
        reason: 'memory-expired-repeat-${candidate.profile.modelLabel}',
        shouldVibrate: warning.urgent,
      );
    }

    _markSeenWithoutSpeech(memory: memory, candidate: candidate, warning: warning);

    return ObstacleAlertDecision.silent(
      'same-situation-muted-${candidate.profile.modelLabel}',
    );
  }

  void markNoCandidate() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastCandidateAt).inMilliseconds;

    if (elapsed >= clearAfterNoCandidateMs) {
      _labelMemory.clear();
    }
  }

  void reset() {
    _labelMemory.clear();
    _lastAnySpeechAt = DateTime.fromMillisecondsSinceEpoch(0);
    _lastCandidateAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _memoryKey(ObstacleCandidate candidate) {
    return '${candidate.profile.label.name}|${candidate.profile.modelLabel}';
  }

  void _markSpoken({
    required DateTime now,
    required _LabelAlertMemory memory,
    required ObstacleCandidate candidate,
    required ObstacleWarning warning,
  }) {
    memory.lastSpokenAt = now;
    memory.lastSeenAt = now;
    memory.lastDirection = candidate.direction;
    memory.lastDistance = candidate.distance;
    memory.lastConfidence = candidate.detection.confidence;
    memory.lastPriority = candidate.profile.priority;
    memory.lastUrgent = warning.urgent;
    memory.lastSignature = warning.signature;
    memory.lastArea = candidate.detection.area;
    memory.lastBottom = candidate.detection.bottom;

    _lastAnySpeechAt = now;
  }

  void _markSeenWithoutSpeech({
    required _LabelAlertMemory memory,
    required ObstacleCandidate candidate,
    required ObstacleWarning warning,
  }) {
    final now = DateTime.now();

    memory.lastSeenAt = now;

    /// Keep the strongest known state so the next speech only happens when the
    /// danger truly escalates, not just because the model keeps detecting it.
    memory.lastConfidence = max(
      memory.lastConfidence ?? 0.0,
      candidate.detection.confidence,
    );
    memory.lastArea = max(memory.lastArea ?? 0.0, candidate.detection.area);
    memory.lastBottom = max(memory.lastBottom ?? 0.0, candidate.detection.bottom);
    memory.lastPriority = max(memory.lastPriority ?? 0, candidate.profile.priority);
    memory.lastUrgent = memory.lastUrgent || warning.urgent;

    if (_distanceRank(candidate.distance) >
        _distanceRank(memory.lastDistance ?? ObstacleDistance.far)) {
      memory.lastDistance = candidate.distance;
    }

    if (candidate.direction == ObstacleDirection.center) {
      memory.lastDirection = candidate.direction;
    }
  }

  int _distanceRank(ObstacleDistance distance) {
    switch (distance) {
      case ObstacleDistance.far:
        return 0;
      case ObstacleDistance.medium:
        return 1;
      case ObstacleDistance.near:
        return 2;
      case ObstacleDistance.veryNear:
        return 3;
    }
  }

  String _changeReason({
    required bool distanceEscalated,
    required bool movedIntoCenter,
    required bool directionChangedStrongly,
    required bool becameUrgent,
    required bool confidenceJump,
    required bool priorityJump,
    required bool biggerAndCloser,
  }) {
    if (distanceEscalated) return 'danger-escalated-distance';
    if (movedIntoCenter || directionChangedStrongly) return 'danger-entered-center';
    if (becameUrgent) return 'became-urgent';
    if (biggerAndCloser) return 'object-became-bigger-closer';
    if (confidenceJump) return 'confidence-jumped';
    if (priorityJump) return 'priority-jumped';
    return 'important-change';
  }
}

class _LabelAlertMemory {
  DateTime? lastSpokenAt;
  DateTime? lastSeenAt;
  ObstacleDirection? lastDirection;
  ObstacleDistance? lastDistance;
  double? lastConfidence;
  double? lastArea;
  double? lastBottom;
  int? lastPriority;
  bool lastUrgent = false;
  String lastSignature = '';
}
