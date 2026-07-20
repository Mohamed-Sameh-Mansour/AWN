import 'package:flutter/widgets.dart';

class AppConstants {
  const AppConstants._();

  static const Duration shortTapLock = Duration(milliseconds: 350);
  static const Duration mediumTapLock = Duration(milliseconds: 600);
}

class HomeConstants {
  const HomeConstants._();

  static const double swipeThreshold = 35.0;
}

class CameraConstants {
  const CameraConstants._();

  static const Duration defaultMinFrameInterval = Duration(milliseconds: 120);
  static const Duration textReaderFrameInterval = Duration(milliseconds: 350);
}

class CurrencyConstants {
  const CurrencyConstants._();

  static const int modelInputSize = 640;

  static const int frameIntervalMs = 380;

  static const int guideCooldownMs = 1800;
  static const int fallbackCooldownMs = 3200;

  static const double minConfidenceForGuidance = 0.45;
  static const double minConfidenceForLock = 0.62;

  static const double centeredMinConfidence = 0.60;

  // الكشف السريع لازم يبقى بثقة عالية جدًا.
  static const double minConfidenceForQuickAnnounce = 0.80;

  // لازم نفس العملة تظهر مرتين ورا بعض.
  static const int quickHitsToAnnounce = 2;

  // أقصى فرق وقت بين الفريمين المتتاليين.
  static const int quickMemoryWindowMs = 2200;

  static const int stableHitsToLock = 2;
  static const double minIouForStability = 0.42;

  static const int shotsCount = 3;
  static const int betweenShotsDelayMs = 250;

  static const double minGoodArea = 0.040;
  static const double maxGoodArea = 0.88;

  static const double horizontalTolerance = 0.18;
  static const double verticalTolerance = 0.14;

  static const double centerX = 0.50;
  static const double centerY = 0.50;
}

class TextReaderConstants {
  const TextReaderConstants._();

  static const Duration uiDebounce = Duration(milliseconds: 120);
  static const Duration tapLock = Duration(milliseconds: 350);
  static const Duration scanTimeout = Duration(seconds: 3);
  static const int minGoodTextLength = 12;
}

class MedicineConstants {
  const MedicineConstants._();

  static const Duration tapLock = Duration(milliseconds: 600);
  static const Duration minFrameInterval = Duration(milliseconds: 120);
}

class ObstacleConstants {
  const ObstacleConstants._();

  static const int frameIntervalMs = 700;
  static const int stableFramesRequired = 3;
  static const int sameSpeechCooldownMs = 3000;
  static const int changeSpeechCooldownMs = 1800;

  static const int modelInputSize = 640;
  static const double confidenceThreshold = 0.30;
  static const double iouThreshold = 0.45;
}

class UiConstants {
  const UiConstants._();

  static const double overlayOpacity = 0.55;
  static const double obstacleOverlayOpacity = 0.58;

  static const Radius cardRadius = Radius.circular(14);
  static const BorderRadius overlayRadius = BorderRadius.all(cardRadius);
}
