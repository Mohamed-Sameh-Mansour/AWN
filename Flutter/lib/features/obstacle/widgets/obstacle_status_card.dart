import 'package:flutter/material.dart';

import 'package:myeye/features/obstacle/models/obstacle_label.dart';
import 'package:myeye/features/obstacle/models/obstacle_ui_state.dart';
import 'package:myeye/features/obstacle/models/obstacle_warning.dart';

class ObstacleStatusCard extends StatelessWidget {
  final ObstacleUiState state;
  final Color primaryColor;
  final Color glassColor;
  final Color mutedText;
  final bool compact;

  const ObstacleStatusCard({
    super.key,
    required this.state,
    required this.primaryColor,
    required this.glassColor,
    required this.mutedText,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final activeDetection = state.detections.isNotEmpty
        ? state.detections.first
        : null;

    final activeLabel = activeDetection?.label ?? ObstacleLabel.unknown;
    final profile = ObstacleClassProfiles.profileOf(activeLabel);

    final hasWarning = state.warning != null;
    final title = _titleText(state, profile);
    final subtitle = _subtitleText(state);
    final distanceText = _distanceText(state.warning);
    final iconData = _iconFor(activeLabel);

    return RepaintBoundary(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 13 : 16,
          vertical: compact ? 13 : 16,
        ),
        decoration: BoxDecoration(
          color: glassColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.96),
            width: 1.35,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.30),
              blurRadius: 24,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.62),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'الحالة',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: primaryColor,
                fontSize: compact ? 15 : 16,
                height: 1,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: primaryColor.withValues(alpha: 0.95),
                    blurRadius: 14,
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 8 : 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _circleIcon(iconData),
                SizedBox(width: compact ? 10 : 12),
                Expanded(
                  child: _centerTextBlock(
                    title: title,
                    subtitle: subtitle,
                    hasWarning: hasWarning,
                  ),
                ),
                if (hasWarning) ...[
                  SizedBox(width: compact ? 10 : 12),
                  _distanceBox(distanceText),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _centerTextBlock({
    required String title,
    required String subtitle,
    required bool hasWarning,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _fitTitleText(title, hasWarning: hasWarning),
        SizedBox(height: compact ? 6 : 7),
        _subtitleTextWidget(subtitle),
      ],
    );
  }

  Widget _fitTitleText(String title, {required bool hasWarning}) {
    final fontSize = _titleFontSize(title, hasWarning: hasWarning);

    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            shadows: [
              Shadow(
                color: primaryColor.withValues(alpha: 0.38),
                blurRadius: 12,
              ),
              const Shadow(
                color: Colors.black54,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subtitleTextWidget(String subtitle) {
    return Text(
      subtitle,
      textAlign: TextAlign.center,
      maxLines: 3,
      overflow: TextOverflow.fade,
      softWrap: true,
      style: TextStyle(
        color: mutedText,
        fontSize: _subtitleFontSize(subtitle),
        height: 1.22,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  double _titleFontSize(String title, {required bool hasWarning}) {
    final normalized = title.trim();
    final length = normalized.length;

    if (normalized == 'جاهز') {
      return compact ? 29 : 33;
    }

    if (normalized == 'يفحص الطريق') {
      return compact ? 23 : 27;
    }

    if (compact) {
      if (length >= 18) return 24;
      if (length >= 13) return 27;
      return hasWarning ? 31 : 33;
    }

    if (length >= 18) return 28;
    if (length >= 13) return 31;
    return hasWarning ? 36 : 38;
  }

  double _subtitleFontSize(String subtitle) {
    final length = subtitle.trim().length;

    if (compact) {
      if (length >= 32) return 12.5;
      if (length >= 22) return 13.5;
      return 14.5;
    }

    if (length >= 32) return 13.5;
    if (length >= 22) return 14.5;
    return 16;
  }

  Widget _circleIcon(IconData icon) {
    final size = compact ? 70.0 : 82.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF021522),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.96),
          width: 1.45,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.30),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.wifi_tethering_rounded,
            color: primaryColor.withValues(alpha: 0.30),
            size: compact ? 56 : 66,
          ),
          Icon(icon, color: const Color(0xFFCFFFFF), size: compact ? 34 : 42),
        ],
      ),
    );
  }

  Widget _distanceBox(String text) {
    final width = compact ? 68.0 : 78.0;
    final height = compact ? 74.0 : 86.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF021522).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.96),
          width: 1.35,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.24),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          softWrap: true,
          style: TextStyle(
            color: const Color(0xFFCFFFFF),
            fontSize: compact ? 18 : 22,
            height: 1.10,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: primaryColor.withValues(alpha: 0.95),
                blurRadius: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _titleText(ObstacleUiState state, ObstacleClassProfile profile) {
    if (!state.scanning) return 'جاهز';

    final warning = state.warning;

    if (warning != null) {
      final objectName = warning.profile.arabicName;
      final direction = _directionTitle(warning.direction);

      if (direction.isEmpty) return objectName;
      return '$objectName $direction';
    }

    if (profile.label != ObstacleLabel.unknown) {
      return profile.arabicName;
    }

    if (state.status.trim().isNotEmpty &&
        state.status.trim() != 'فحص الطريق' &&
        state.status.trim() != 'يفحص الطريق') {
      return state.status.trim();
    }

    return 'يفحص الطريق';
  }

  String _subtitleText(ObstacleUiState state) {
    if (!state.scanning) return 'اضغط مرتين لبدء الكشف';

    if (state.warning != null) {
      return _guideFromWarning(state.warning!);
    }

    if (state.status == 'جاري التأكيد') {
      return 'جارٍ تأكيد العائق أمامك';
    }

    final guide = state.guide.trim();

    if (guide.isNotEmpty) {
      if (guide.contains('لا يوجد عائق')) {
        return 'لا يوجد عائق مؤكد';
      }

      return guide;
    }

    return 'ثبت الكاميرا أمامك';
  }

  String _distanceText(ObstacleWarning? warning) {
    if (warning == null) return '';

    switch (warning.distance) {
      case ObstacleDistance.veryNear:
        return 'قريب\nجدًا';
      case ObstacleDistance.near:
        return 'قريب';
      case ObstacleDistance.medium:
        return 'متوسط';
      case ObstacleDistance.far:
        return 'بعيد';
    }
  }

  String _directionTitle(ObstacleDirection direction) {
    switch (direction) {
      case ObstacleDirection.center:
        return 'أمامك';
      case ObstacleDirection.left:
        return 'على اليسار';
      case ObstacleDirection.right:
        return 'على اليمين';
    }
  }

  String _guideFromWarning(ObstacleWarning warning) {
    switch (warning.direction) {
      case ObstacleDirection.center:
        if (warning.distance == ObstacleDistance.veryNear ||
            warning.distance == ObstacleDistance.near) {
          return 'خفف السرعة واستعد للتوقف';
        }
        return 'استمر بحذر';
      case ObstacleDirection.left:
        return 'تحرك قليلًا إلى اليمين';
      case ObstacleDirection.right:
        return 'تحرك قليلًا إلى اليسار';
    }
  }

  IconData _iconFor(ObstacleLabel label) {
    switch (label) {
      case ObstacleLabel.person:
        return Icons.directions_walk_rounded;
      case ObstacleLabel.vehicle:
        return Icons.directions_car_filled_rounded;
      case ObstacleLabel.pothole:
        return Icons.warning_amber_rounded;
      case ObstacleLabel.stairs:
        return Icons.stairs_rounded;
      case ObstacleLabel.openedDoor:
        return Icons.door_front_door_rounded;
      case ObstacleLabel.poleBollard:
        return Icons.signpost_rounded;
      case ObstacleLabel.animal:
        return Icons.pets_rounded;
      case ObstacleLabel.crosswalk:
        return Icons.directions_walk_rounded;
      case ObstacleLabel.trafficLight:
        return Icons.traffic_rounded;
      case ObstacleLabel.edgeSidewalk:
        return Icons.border_bottom_rounded;
      case ObstacleLabel.obstacle:
        return Icons.report_problem_rounded;
      case ObstacleLabel.cane:
        return Icons.accessibility_new_rounded;
      case ObstacleLabel.unknown:
        return Icons.sensors_rounded;
    }
  }
}
