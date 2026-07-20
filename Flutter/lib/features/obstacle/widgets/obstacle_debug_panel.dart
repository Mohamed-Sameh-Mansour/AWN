import 'package:flutter/material.dart';

class ObstacleDebugPanel extends StatelessWidget {
  final String debugText;
  final Color primaryColor;

  const ObstacleDebugPanel({
    super.key,
    required this.debugText,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.18)),
      ),
      child: Text(
        debugText,
        textDirection: TextDirection.ltr,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFC9D5D0),
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          height: 1.25,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
