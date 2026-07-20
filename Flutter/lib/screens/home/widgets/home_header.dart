import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  final VoidCallback onSettingsPressed;

  const HomeHeader({super.key, required this.onSettingsPressed});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 390;

    return SizedBox(
      height: narrow ? 90 : 100,
      child: Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _MyEyeLogo(width: narrow ? 155 : 175, height: narrow ? 88 : 98),
          Expanded(
            child: Transform.translate(
              offset: Offset(narrow ? -10 : -12, 0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RichText(
                  maxLines: 1,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Awn-',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: narrow ? 40 : 44,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                        ),
                      ),
                      TextSpan(
                        text: 'عون',
                        style: TextStyle(
                          color: const Color(0xFF00E5E5),
                          fontSize: narrow ? 40 : 44,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: narrow ? 4 : 8),
          _SettingsButton(onPressed: onSettingsPressed, size: narrow ? 58 : 62),
        ],
      ),
    );
  }
}

class _MyEyeLogo extends StatelessWidget {
  final double width;
  final double height;

  const _MyEyeLogo({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Transform.scale(
        scale: 1.50,
        alignment: Alignment.center,
        child: Image.asset(
          'assets/images/myeye_logo.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: width,
              height: height,
              color: Colors.red,
              alignment: Alignment.center,
              child: const Text(
                'LOGO ERROR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double size;

  const _SettingsButton({required this.onPressed, required this.size});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.055),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.42),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.07),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            Icons.settings_rounded,
            color: Colors.white,
            size: size * 0.52,
          ),
        ),
      ),
    );
  }
}
