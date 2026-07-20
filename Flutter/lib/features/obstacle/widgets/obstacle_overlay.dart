import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:myeye/features/obstacle/models/obstacle_detection_result.dart';
import 'package:myeye/features/obstacle/models/obstacle_label.dart';

class ObstacleOverlay extends StatelessWidget {
  final List<ObstacleDetectionResult> detections;
  final bool scanning;
  final Color primaryColor;

  const ObstacleOverlay({
    super.key,
    required this.detections,
    required this.scanning,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ObstacleOverlayPainter(
        detections: detections,
        scanning: scanning,
        primaryColor: primaryColor,
      ),
    );
  }
}

class _ObstacleOverlayPainter extends CustomPainter {
  final List<ObstacleDetectionResult> detections;
  final bool scanning;
  final Color primaryColor;

  _ObstacleOverlayPainter({
    required this.detections,
    required this.scanning,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scanning) _drawNeonWalkingPath(canvas, size);

    for (final detection in detections.take(7)) {
      final profile = ObstacleClassProfiles.profileOf(detection.label);

      final rect = Rect.fromLTRB(
        detection.box.left * size.width,
        detection.box.top * size.height,
        detection.box.right * size.width,
        detection.box.bottom * size.height,
      );

      final isWarning = profile.role == ObstacleClassRole.warning;
      final color = isWarning ? primaryColor : const Color(0xFF9EFFFF);

      _drawNeonCorners(canvas, rect, color);
      _drawDetectionLabel(
        canvas,
        rect,
        '${profile.arabicName} ${(detection.confidence * 100).round()}%',
        color,
      );
    }
  }

  void _drawNeonWalkingPath(Canvas canvas, Size size) {
    final centerX = size.width * 0.50;
    final bottomY = size.height * 0.91;
    final topY = size.height * 0.55;

    final steps = <_PathStep>[
      _PathStep(width: size.width * 0.31, y: bottomY),
      _PathStep(width: size.width * 0.26, y: bottomY - 42),
      _PathStep(width: size.width * 0.21, y: bottomY - 84),
      _PathStep(width: size.width * 0.16, y: bottomY - 126),
      _PathStep(width: size.width * 0.105, y: bottomY - 168),
      _PathStep(width: size.width * 0.065, y: topY),
    ];

    for (final step in steps) {
      final start = Offset(centerX - step.width / 2, step.y);
      final end = Offset(centerX + step.width / 2, step.y);
      _drawGlowLine(canvas: canvas, start: start, end: end, color: primaryColor, mainWidth: 3.2);
    }

    final leftGuide = Path()
      ..moveTo(centerX - size.width * 0.155, bottomY)
      ..quadraticBezierTo(centerX - size.width * 0.12, size.height * 0.73, centerX - size.width * 0.036, topY);

    final rightGuide = Path()
      ..moveTo(centerX + size.width * 0.155, bottomY)
      ..quadraticBezierTo(centerX + size.width * 0.12, size.height * 0.73, centerX + size.width * 0.036, topY);

    _drawGlowPath(canvas, leftGuide, primaryColor.withValues(alpha: 0.35), 1.25);
    _drawGlowPath(canvas, rightGuide, primaryColor.withValues(alpha: 0.35), 1.25);
  }

  void _drawGlowLine({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required Color color,
    required double mainWidth,
  }) {
    final glowPaint1 = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..strokeWidth = mainWidth + 12
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final glowPaint2 = Paint()
      ..color = color.withValues(alpha: 0.34)
      ..strokeWidth = mainWidth + 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final mainPaint = Paint()
      ..color = color.withValues(alpha: 0.94)
      ..strokeWidth = mainWidth
      ..strokeCap = StrokeCap.round;

    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.58)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, glowPaint1);
    canvas.drawLine(start, end, glowPaint2);
    canvas.drawLine(start, end, mainPaint);
    canvas.drawLine(start, end, corePaint);
  }

  void _drawGlowPath(Canvas canvas, Path path, Color color, double width) {
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width + 8
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.45);

    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);
  }

  void _drawNeonCorners(Canvas canvas, Rect rect, Color color) {
    final radius = math.min(18.0, math.min(rect.width, rect.height) * 0.14);
    final cornerLength = math.min(48.0, math.min(rect.width, rect.height) * 0.33);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11);

    final glowPaint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.44)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.98);

    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.75);

    final cornerPath = _cornerPath(rect, radius, cornerLength);

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.05);

    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), fillPaint);
    canvas.drawPath(cornerPath, glowPaint);
    canvas.drawPath(cornerPath, glowPaint2);
    canvas.drawPath(cornerPath, mainPaint);
    canvas.drawPath(cornerPath, corePaint);
  }

  Path _cornerPath(Rect rect, double radius, double length) {
    final path = Path();

    path.moveTo(rect.left + radius, rect.top);
    path.lineTo(rect.left + length, rect.top);
    path.moveTo(rect.left, rect.top + radius);
    path.lineTo(rect.left, rect.top + length);

    path.moveTo(rect.right - radius, rect.top);
    path.lineTo(rect.right - length, rect.top);
    path.moveTo(rect.right, rect.top + radius);
    path.lineTo(rect.right, rect.top + length);

    path.moveTo(rect.left + radius, rect.bottom);
    path.lineTo(rect.left + length, rect.bottom);
    path.moveTo(rect.left, rect.bottom - radius);
    path.lineTo(rect.left, rect.bottom - length);

    path.moveTo(rect.right - radius, rect.bottom);
    path.lineTo(rect.right - length, rect.bottom);
    path.moveTo(rect.right, rect.bottom - radius);
    path.lineTo(rect.right, rect.bottom - length);

    return path;
  }

  void _drawDetectionLabel(Canvas canvas, Rect rect, String text, Color color) {
    final paragraphStyle = ui.ParagraphStyle(
      textDirection: ui.TextDirection.rtl,
      maxLines: 1,
      ellipsis: '…',
    );

    final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(
        ui.TextStyle(
          color: const Color(0xFF00141B),
          fontSize: 12,
          fontWeight: ui.FontWeight.w900,
        ),
      )
      ..addText(text);

    final paragraph = paragraphBuilder.build()..layout(const ui.ParagraphConstraints(width: 145));

    final labelWidth = (paragraph.width + 24).clamp(84.0, 162.0).toDouble();
    final labelTop = (rect.top - 32).clamp(8.0, 10000.0).toDouble();
    final labelRect = Rect.fromLTWH(rect.left, labelTop, labelWidth, 26);

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.96)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.2);

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawRRect(RRect.fromRectAndRadius(labelRect.inflate(3), const Radius.circular(999)), glowPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(labelRect, const Radius.circular(999)), bgPaint);
    canvas.drawParagraph(paragraph, Offset(labelRect.left + 12, labelRect.top + 5));
  }

  @override
  bool shouldRepaint(covariant _ObstacleOverlayPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.scanning != scanning ||
        oldDelegate.primaryColor != primaryColor;
  }
}

class _PathStep {
  final double width;
  final double y;

  const _PathStep({required this.width, required this.y});
}
