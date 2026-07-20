enum AppFeature {
  obstacle,
  objectDetector,
  textReader,
  currency,
  medicine,
}

extension AppFeatureContent on AppFeature {
  String get title {
    switch (this) {
      case AppFeature.obstacle:
        return 'كاشف العوائق';
      case AppFeature.objectDetector:
        return 'كاشف الأشياء';
      case AppFeature.textReader:
        return 'قارئ النصوص';
      case AppFeature.currency:
        return 'قارئ العملات';
      case AppFeature.medicine:
        return 'قارئ الأدوية';
    }
  }

  String get hint {
    switch (this) {
      case AppFeature.obstacle:
        return 'اضغط مرتين لفتح كاشف العوائق المباشر.';
      case AppFeature.objectDetector:
        return 'اضغط مرتين لفتح كاشف الأشياء.';
      case AppFeature.textReader:
        return 'اضغط مرتين لفتح قارئ النصوص.';
      case AppFeature.currency:
        return 'اضغط مرتين لفتح قارئ العملات.';
      case AppFeature.medicine:
        return 'اضغط مرتين لفتح قارئ الأدوية.';
    }
  }
}
