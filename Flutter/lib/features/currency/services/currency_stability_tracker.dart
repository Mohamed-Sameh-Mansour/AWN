import 'dart:ui';

import 'package:myeye/core/camera/camera_utils.dart';
import 'package:myeye/core/constants/app_constants.dart';

class CurrencyStabilityTracker {
  int _stableCount = 0;
  Rect? _previousBox;
  String _previousLabel = '';

  void reset() {
    _stableCount = 0;
    _previousBox = null;
    _previousLabel = '';
  }

  bool update({
    required Rect box,
    required String label,
    required double confidence,
  }) {
    if (confidence < CurrencyConstants.minConfidenceForLock) {
      reset();
      return false;
    }

    if (_previousLabel.isEmpty) {
      _previousLabel = label;
    }

    if (_previousLabel != label) {
      reset();
      _previousLabel = label;
      _previousBox = box;
      return false;
    }

    if (_previousBox != null) {
      final overlap = CameraUtils.iouRect(_previousBox!, box);

      if (overlap < CurrencyConstants.minIouForStability) {
        _stableCount = 0;
        _previousBox = box;
        return false;
      }
    }

    _previousBox = box;
    _stableCount++;

    return _stableCount >= CurrencyConstants.stableHitsToLock;
  }
}
