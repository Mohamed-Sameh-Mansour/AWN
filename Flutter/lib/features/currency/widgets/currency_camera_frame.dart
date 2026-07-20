import 'package:flutter/material.dart';

class CurrencyCameraFrame extends StatelessWidget {
  const CurrencyCameraFrame({
    super.key,
    required this.preview,
    required this.cameraIsLive,
    required this.statusText,
    required this.primaryGreen,
  });

  final Widget preview;
  final bool cameraIsLive;
  final String statusText;
  final Color primaryGreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: primaryGreen, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withValues(alpha: 0.20),
            blurRadius: 24,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.45),
              child: cameraIsLive ? SizedBox.expand(child: preview) : preview,
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.22),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 18,
              left: 18,
              child: _TinyStatus(
                statusText: statusText,
                primaryGreen: primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyStatus extends StatelessWidget {
  const _TinyStatus({required this.statusText, required this.primaryGreen});

  final String statusText;
  final Color primaryGreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryGreen,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
