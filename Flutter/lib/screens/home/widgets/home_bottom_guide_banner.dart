import 'dart:math' as math;

import 'package:flutter/material.dart';

class HomeBottomGuideBanner extends StatelessWidget {
  final bool isEnglish;

  const HomeBottomGuideBanner({super.key, required this.isEnglish});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 390;

    return Container(
      height: narrow ? 88 : 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF042A3C).withValues(alpha: 0.86),
            const Color(0xFF061221).withValues(alpha: 0.98),
            const Color(0xFF042A3C).withValues(alpha: 0.86),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.82),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.22),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _BannerLinesPainter())),
            Directionality(
              textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '✦',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEnglish
                          ? 'Your smart vision assistant is always ready'
                          : 'مساعدك الذكي للرؤية، جاهز دائماً',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: const Color(0xFFBFFFFF),
                        fontSize: isEnglish
                            ? (narrow ? 14.5 : 16.0)
                            : (narrow ? 18 : 20),
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      isEnglish
                          ? 'Swipe to choose a feature  •  Double tap to start'
                          : 'اسحب لاختيار ميزة  •  اضغط مرتين للبدء',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: isEnglish
                            ? (narrow ? 11.8 : 13.0)
                            : (narrow ? 13.5 : 14.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    final linePaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final leftRect = Rect.fromLTWH(
      -size.width * 0.08,
      8,
      size.width * 0.38,
      size.height - 16,
    );

    final rightRect = Rect.fromLTWH(
      size.width * 0.70,
      8,
      size.width * 0.38,
      size.height - 16,
    );

    canvas.drawArc(leftRect, -math.pi * 0.58, math.pi * 1.15, false, glowPaint);

    canvas.drawArc(
      leftRect.deflate(12),
      -math.pi * 0.58,
      math.pi * 1.15,
      false,
      linePaint,
    );

    canvas.drawArc(rightRect, math.pi * 0.42, math.pi * 1.15, false, glowPaint);

    canvas.drawArc(
      rightRect.deflate(12),
      math.pi * 0.42,
      math.pi * 1.15,
      false,
      linePaint,
    );

    final dotPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.70);

    canvas.drawCircle(
      Offset(size.width * 0.04, size.height * 0.22),
      2.0,
      dotPaint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.07, size.height * 0.72),
      1.8,
      dotPaint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.96, size.height * 0.22),
      2.0,
      dotPaint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.93, size.height * 0.72),
      1.8,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
