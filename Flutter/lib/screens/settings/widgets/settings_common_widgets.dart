import 'package:flutter/material.dart';

class SettingsGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final Color glowColor;

  const SettingsGlassCard({
    super.key,
    required this.child,
    required this.padding,
    this.borderColor = const Color(0xFF00E5FF),
    this.glowColor = const Color(0xFF00E5FF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF071A2A).withValues(alpha: 0.90),
            const Color(0xFF020814).withValues(alpha: 0.98),
            const Color(0xFF04111F).withValues(alpha: 0.96),
          ],
        ),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.58),
          width: 1.15,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.16),
            blurRadius: 28,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SettingsCircleIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const SettingsCircleIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 74,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.34),
            const Color(0xFF061221).withValues(alpha: 0.95),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.70), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

class SettingsSectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const SettingsSectionHeader({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final narrow = MediaQuery.sizeOf(context).width < 390;

    return Row(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      children: [
        SettingsCircleIconBadge(
          icon: icon,
          color: iconColor,
          size: narrow ? 62 : 70,
        ),
        SizedBox(width: narrow ? 14 : 18),
        Expanded(
          child: Column(
            crossAxisAlignment: isRtl
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: narrow ? 22 : 25,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: iconColor,
                  fontSize: narrow ? 17 : 19,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
