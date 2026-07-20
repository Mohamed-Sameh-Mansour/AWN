import 'package:flutter/material.dart';

import 'package:myeye/screens/settings/widgets/settings_common_widgets.dart';

class SettingsAboutCard extends StatelessWidget {
  final bool isEnglish;
  final VoidCallback onTap;

  const SettingsAboutCard({
    super.key,
    required this.isEnglish,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final narrow = MediaQuery.sizeOf(context).width < 390;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: narrow ? 96 : 106,
          padding: EdgeInsets.symmetric(horizontal: narrow ? 18 : 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                const Color(0xFF061221).withValues(alpha: 0.95),
                const Color(0xFF042A3C).withValues(alpha: 0.58),
                const Color(0xFF061221).withValues(alpha: 0.95),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.62),
              width: 1.15,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.16),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            children: [
              const SettingsCircleIconBadge(
                icon: Icons.info_outline_rounded,
                color: Color(0xFF22F3FF),
                size: 58,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  isEnglish ? 'About us' : 'من نحن',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: narrow ? 22 : 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                isRtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: const Color(0xFF69F7FF),
                size: 36,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
