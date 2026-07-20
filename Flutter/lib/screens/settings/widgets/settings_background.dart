import 'package:flutter/material.dart';

class SettingsBackground extends StatelessWidget {
  const SettingsBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF01030B), Color(0xFF031020), Color(0xFF020712)],
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            top: -120,
            left: -120,
            child: _GlowCircle(size: 320, color: Color(0x2E00E5FF)),
          ),
          Positioned(
            top: 260,
            right: -150,
            child: _GlowCircle(size: 360, color: Color(0x1F00D38D)),
          ),
          Positioned(
            bottom: -160,
            left: -120,
            child: _GlowCircle(size: 320, color: Color(0x22006CFF)),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
