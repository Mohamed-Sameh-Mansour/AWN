import 'package:flutter/material.dart';

import '../models/home_feature_meta.dart';

class HomeFeatureCard extends StatelessWidget {
  final HomeFeatureMeta meta;
  final bool selected;
  final double height;
  final bool isEnglish;
  final VoidCallback onTap;

  const HomeFeatureCard({
    super.key,
    required this.meta,
    required this.selected,
    required this.height,
    required this.isEnglish,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? meta.glowColor.withValues(alpha: 0.92)
        : meta.glowColor.withValues(alpha: 0.36);

    final narrow = MediaQuery.sizeOf(context).width < 390;
    final iconSize = narrow ? 66.0 : 74.0;
    final titleSize = isEnglish
        ? (narrow ? 18.2 : 19.6)
        : (narrow ? 20.5 : 22.5);
    final subtitleSize = isEnglish
        ? (narrow ? 12.5 : 13.6)
        : (narrow ? 14.0 : 15.2);
    final chevronSize = narrow ? 34.0 : 38.0;

    final semanticSubtitle = meta.subtitle(isEnglish).replaceAll('\n', ' ');

    return Semantics(
      button: true,
      selected: selected,
      label:
          '${meta.title(isEnglish)}. $semanticSubtitle. ${isEnglish ? 'Double tap to start.' : 'اضغط مرتين للبدء.'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: height,
            padding: EdgeInsets.fromLTRB(
              narrow ? 12 : 16,
              narrow ? 10 : 12,
              narrow ? 12 : 16,
              narrow ? 10 : 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF06101E).withValues(alpha: 0.94),
                  const Color(0xFF020814).withValues(alpha: 0.98),
                  meta.color.withValues(alpha: selected ? 0.18 : 0.09),
                ],
              ),
              border: Border.all(
                color: borderColor,
                width: selected ? 1.45 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: meta.glowColor.withValues(
                    alpha: selected ? 0.32 : 0.14,
                  ),
                  blurRadius: selected ? 28 : 16,
                  spreadRadius: selected ? 1 : 0,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                _FeatureIconTile(meta: meta, size: iconSize),
                SizedBox(width: narrow ? 12 : 16),
                Expanded(
                  child: Directionality(
                    textDirection: isEnglish
                        ? TextDirection.ltr
                        : TextDirection.rtl,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: isEnglish
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: isEnglish
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: isEnglish
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Text(
                              meta.title(isEnglish),
                              textAlign: isEnglish
                                  ? TextAlign.left
                                  : TextAlign.right,
                              maxLines: 1,
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: titleSize,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: narrow ? 4 : 6),
                        Text(
                          meta.subtitle(isEnglish),
                          textAlign: isEnglish
                              ? TextAlign.left
                              : TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.66),
                            fontSize: subtitleSize,
                            fontWeight: FontWeight.w500,
                            height: 1.16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: narrow ? 8 : 10),
                Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white.withValues(alpha: 0.96),
                  size: chevronSize,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureIconTile extends StatelessWidget {
  final HomeFeatureMeta meta;
  final double size;

  const _FeatureIconTile({required this.meta, required this.size});

  @override
  Widget build(BuildContext context) {
    final iconScale = size / 86.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            meta.color.withValues(alpha: 0.96),
            meta.color.withValues(alpha: 0.52),
            const Color(0xFF03101B).withValues(alpha: 0.90),
          ],
        ),
        border: Border.all(
          color: meta.glowColor.withValues(alpha: 0.88),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: meta.glowColor.withValues(alpha: 0.34),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Transform.scale(
        scale: iconScale.clamp(0.78, 0.96),
        child: _FeatureIcon(kind: meta.iconKind),
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  final HomeFeatureIconKind kind;

  const _FeatureIcon({required this.kind});

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case HomeFeatureIconKind.obstacle:
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.sensors_rounded,
              color: const Color(0xFF00E5FF).withValues(alpha: 0.88),
              size: 60,
            ),
            const Icon(
              Icons.directions_walk_rounded,
              color: Colors.white,
              size: 52,
            ),
          ],
        );

      case HomeFeatureIconKind.objectDetector:
        return const Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.crop_free_rounded, color: Colors.white, size: 56),
            Icon(Icons.inventory_2_rounded, color: Colors.white, size: 34),
          ],
        );

      case HomeFeatureIconKind.text:
        return const Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.crop_free_rounded, color: Colors.white, size: 58),
            Icon(Icons.text_fields_rounded, color: Colors.white, size: 44),
          ],
        );

      case HomeFeatureIconKind.currency:
        return const Icon(
          Icons.payments_outlined,
          color: Colors.white,
          size: 54,
        );

      case HomeFeatureIconKind.medicine:
        return const Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.medication_liquid_rounded,
              color: Colors.white,
              size: 54,
            ),
            Positioned(
              right: 14,
              bottom: 14,
              child: Icon(
                Icons.local_hospital_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ],
        );    }
  }
}
