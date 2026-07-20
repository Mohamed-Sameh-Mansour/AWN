import 'package:flutter/material.dart';

class SettingsHeader extends StatelessWidget {
  final bool isEnglish;
  final VoidCallback onBack;

  const SettingsHeader({
    super.key,
    required this.isEnglish,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 390;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          _BackButtonGlow(onTap: onBack, size: narrow ? 58 : 64),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              isEnglish ? 'Settings' : 'الإعدادات',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: Colors.white,
                fontSize: narrow ? 34 : 38,
                fontWeight: FontWeight.w800,
                letterSpacing: isEnglish ? -0.6 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButtonGlow extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const _BackButtonGlow({required this.onTap, required this.size});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: const Color(0xFF062033).withValues(alpha: 0.70),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.55),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.20),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF69F7FF),
            size: 28,
          ),
        ),
      ),
    );
  }
}
