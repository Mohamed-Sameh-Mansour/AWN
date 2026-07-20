import 'dart:ui';

import 'package:myeye/core/constants/app_constants.dart';

class CurrencyGuidanceService {
  const CurrencyGuidanceService();

  String compute({
    required Rect box,
    required double confidence,
    required int inputSize,
  }) {
    final cx = _normalize(box.center.dx, inputSize);
    final cy = _normalize(box.center.dy, inputSize);
    final w = _normalize(box.width, inputSize);
    final h = _normalize(box.height, inputSize);
    final area = w * h;

    if (area < CurrencyConstants.minGoodArea) {
      return 'قرّب الموبايل شوية';
    }

    if (area > CurrencyConstants.maxGoodArea) {
      return 'ابعِد الموبايل شوية';
    }

    String horizontalMove = '';
    String verticalMove = '';

    if (cx <
        CurrencyConstants.centerX - CurrencyConstants.horizontalTolerance) {
      horizontalMove = 'حرّك الموبايل شمال';
    } else if (cx >
        CurrencyConstants.centerX + CurrencyConstants.horizontalTolerance) {
      horizontalMove = 'حرّك الموبايل يمين';
    }

    if (cy < CurrencyConstants.centerY - CurrencyConstants.verticalTolerance) {
      verticalMove = 'نزّل ايدك لتحت';
    } else if (cy >
        CurrencyConstants.centerY + CurrencyConstants.verticalTolerance) {
      verticalMove = 'طلّع ايدك لفوق';
    }

    if (confidence >= CurrencyConstants.centeredMinConfidence &&
        horizontalMove.isEmpty &&
        verticalMove.isEmpty) {
      return '';
    }

    if (confidence < CurrencyConstants.minConfidenceForGuidance &&
        horizontalMove.isEmpty &&
        verticalMove.isEmpty) {
      return 'خلّي العملة واضحة قدام الكاميرا';
    }

    if (horizontalMove.isEmpty && verticalMove.isEmpty) {
      return '';
    }

    if (horizontalMove.isNotEmpty && verticalMove.isNotEmpty) {
      return '$horizontalMove… $verticalMove';
    }

    return horizontalMove.isNotEmpty ? horizontalMove : verticalMove;
  }

  double _normalize(double value, int inputSize) {
    if (inputSize <= 0) return value;

    if (value > 2.0) {
      return value / inputSize;
    }

    return value;
  }
}
