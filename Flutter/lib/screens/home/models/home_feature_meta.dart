import 'package:flutter/material.dart';

import '../../../core/features/app_feature.dart';

enum HomeFeatureIconKind {
  obstacle,
  objectDetector,
  text,
  currency,
  medicine,
}

class HomeFeatureMeta {
  final String titleAr;
  final String subtitleAr;
  final String titleEn;
  final String subtitleEn;
  final String speechHint;
  final Color color;
  final Color glowColor;
  final HomeFeatureIconKind iconKind;

  const HomeFeatureMeta({
    required this.titleAr,
    required this.subtitleAr,
    required this.titleEn,
    required this.subtitleEn,
    required this.speechHint,
    required this.color,
    required this.glowColor,
    required this.iconKind,
  });

  String title(bool isEnglish) => isEnglish ? titleEn : titleAr;

  String subtitle(bool isEnglish) => isEnglish ? subtitleEn : subtitleAr;
}

class HomeFeatureMetaRepository {
  const HomeFeatureMetaRepository._();

  static HomeFeatureMeta metaOf(AppFeature feature) {
    switch (feature) {
      case AppFeature.obstacle:
        return const HomeFeatureMeta(
          titleAr: 'كاشف العوائق',
          subtitleAr: 'اكتشف العوائق\nمن حولك',
          titleEn: 'Obstacle Detector',
          subtitleEn: 'Detect obstacles\naround you',
          speechHint: 'اكتشف العوائق من حولك',
          color: Color(0xFF00D9F5),
          glowColor: Color(0xFF00E5FF),
          iconKind: HomeFeatureIconKind.obstacle,
        );

      case AppFeature.objectDetector:
        return const HomeFeatureMeta(
          titleAr: 'كاشف الأشياء',
          subtitleAr: 'تعرّف على الأشياء\nمن حولك',
          titleEn: 'Object Detector',
          subtitleEn: 'Recognize objects\naround you',
          speechHint: 'تعرّف على الأشياء من حولك',
          color: Color(0xFF167BFF),
          glowColor: Color(0xFF35A7FF),
          iconKind: HomeFeatureIconKind.objectDetector,
        );

      case AppFeature.textReader:
        return const HomeFeatureMeta(
          titleAr: 'قارئ النصوص',
          subtitleAr: 'اقرأ النصوص من\nالكاميرا مباشرة',
          titleEn: 'Text Reader',
          subtitleEn: 'Read text directly\nfrom camera',
          speechHint: 'اقرأ النصوص من الكاميرا مباشرة',
          color: Color(0xFF7C35FF),
          glowColor: Color(0xFF8C4DFF),
          iconKind: HomeFeatureIconKind.text,
        );

      case AppFeature.currency:
        return const HomeFeatureMeta(
          titleAr: 'قارئ العملات',
          subtitleAr: 'تعرّف على العملات\nواسمع القيمة',
          titleEn: 'Currency Reader',
          subtitleEn: 'Identify currency\nand hear value',
          speechHint: 'تعرّف على العملات واسمع القيمة',
          color: Color(0xFF00C77B),
          glowColor: Color(0xFF00E59A),
          iconKind: HomeFeatureIconKind.currency,
        );

      case AppFeature.medicine:
        return const HomeFeatureMeta(
          titleAr: 'قارئ الأدوية',
          subtitleAr: 'تعرّف على الأدوية\nواسمع التفاصيل',
          titleEn: 'Medicine Reader',
          subtitleEn: 'Recognize medicine\nand hear details',
          speechHint: 'تعرّف على الأدوية واسمع التفاصيل',
          color: Color(0xFFFF8A00),
          glowColor: Color(0xFFFFB000),
          iconKind: HomeFeatureIconKind.medicine,
        );
    }
  }
}
