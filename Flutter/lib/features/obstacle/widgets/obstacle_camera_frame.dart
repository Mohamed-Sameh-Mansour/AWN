import 'package:flutter/material.dart';

import 'package:myeye/features/obstacle/models/obstacle_detection_result.dart';
import 'package:myeye/features/obstacle/widgets/obstacle_overlay.dart';

class ObstacleCameraFrame extends StatelessWidget {
  final Widget preview;
  final bool cameraIsLive;
  final bool scanning;
  final String statusText;
  final List<ObstacleDetectionResult> detections;
  final Color primaryColor;

  const ObstacleCameraFrame({
    super.key,
    required this.preview,
    required this.cameraIsLive,
    required this.scanning,
    required this.statusText,
    required this.detections,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.28),
              blurRadius: 28,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: cameraIsLive
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height,
                          child: preview,
                        ),
                      )
                    : preview,
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: ObstacleOverlay(
                  detections: detections,
                  scanning: scanning,
                  primaryColor: primaryColor,
                ),
              ),
              Positioned(top: 18, left: 18, child: _statusChip()),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.92),
                        width: 1.45,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xD9041524),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.85),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.26),
            blurRadius: 18,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scanning ? primaryColor : Colors.white38,
              boxShadow: scanning
                  ? [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.95),
                        blurRadius: 10,
                        spreadRadius: 1.5,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: scanning ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              shadows: scanning
                  ? [Shadow(color: primaryColor.withValues(alpha: 0.45), blurRadius: 10)]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
