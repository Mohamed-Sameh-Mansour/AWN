import 'dart:math' as math;

import 'package:camera/camera.dart';

import 'package:myeye/core/camera/camera_session.dart';
import 'package:myeye/core/camera/input_frame.dart';

class AutoFlashService {
  final int sampleCount;

  final double turnOnLuminance;
  final double turnOffLuminance;

  final double darkPixelLuminance;
  final double turnOffMaxDarkPixelRatio;

  final int darkFramesToTurnOn;
  final int brightFramesToTurnOff;

  final Duration minCheckInterval;
  final Duration minTorchOnDuration;

  final bool autoTurnOffWhenBright;

  bool _torchOn = false;
  bool _changing = false;

  int _darkFrames = 0;
  int _brightFrames = 0;

  DateTime _lastCheck = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastTorchChangedAt = DateTime.fromMillisecondsSinceEpoch(0);

  AutoFlashService({
    this.sampleCount = 900,
    this.turnOnLuminance = 48.0,
    this.turnOffLuminance = 110.0,
    this.darkPixelLuminance = 55.0,
    this.turnOffMaxDarkPixelRatio = 0.18,
    this.darkFramesToTurnOn = 2,
    this.brightFramesToTurnOff = 6,
    this.minCheckInterval = const Duration(milliseconds: 450),
    this.minTorchOnDuration = const Duration(seconds: 3),
    this.autoTurnOffWhenBright = true,
  });

  bool get isTorchOn => _torchOn;

  bool get isChanging => _changing;

  void setKnownTorchState(bool enabled) {
    _torchOn = enabled;
    _darkFrames = 0;
    _brightFrames = 0;
    _lastTorchChangedAt = DateTime.now();
  }

  Future<void> updateFromFrame({
    required InputFrame frame,
    required CameraSessionController? session,
  }) async {
    if (session == null) return;

    final now = DateTime.now();

    if (now.difference(_lastCheck) < minCheckInterval) {
      return;
    }

    _lastCheck = now;

    final sample = _sampleLuminance(frame);

    if (!_torchOn) {
      if (sample.average <= turnOnLuminance) {
        _darkFrames++;
      } else {
        _darkFrames = math.max(0, _darkFrames - 1);
      }

      if (_darkFrames >= darkFramesToTurnOn) {
        _darkFrames = 0;
        _brightFrames = 0;

        await _setTorch(session: session, enabled: true);
      }

      return;
    }

    if (!autoTurnOffWhenBright) {
      return;
    }

    if (now.difference(_lastTorchChangedAt) < minTorchOnDuration) {
      _brightFrames = 0;
      return;
    }

    /*
      مهم:
      لما الفلاش يشتغل في مكان ضلمة، متوسط الإضاءة ممكن يعلى بسبب الفلاش نفسه.
      فمش كفاية نقول average عالي = اقفل الفلاش.

      عشان كده بنشوف حاجتين:
      1) متوسط الإضاءة عالي فعلًا.
      2) نسبة البيكسلات الضلمة قليلة جدًا.

      لو لسه فيه أجزاء كتير ضلمة في الصورة، يبقى المكان مش منور كفاية
      والفلاش لازم يفضل شغال.
    */
    final sceneLooksBright =
        sample.average >= turnOffLuminance &&
        sample.darkPixelRatio <= turnOffMaxDarkPixelRatio;

    if (sceneLooksBright) {
      _brightFrames++;
    } else {
      _brightFrames = 0;
    }

    if (_brightFrames >= brightFramesToTurnOff) {
      _darkFrames = 0;
      _brightFrames = 0;

      await _setTorch(session: session, enabled: false);
    }
  }

  Future<void> turnOff(CameraSessionController? session) async {
    _darkFrames = 0;
    _brightFrames = 0;

    if (!_torchOn && !_changing) return;

    if (session == null) {
      _markTorchState(false);
      return;
    }

    for (int i = 0; i < 5; i++) {
      if (!_changing) break;
      await Future.delayed(const Duration(milliseconds: 80));
    }

    await _setTorch(session: session, enabled: false, force: true);
  }

  Future<void> dispose(CameraSessionController? session) async {
    await turnOff(session);
  }

  double averageLuminance(InputFrame frame) {
    return _sampleLuminance(frame).average;
  }

  _LuminanceSample _sampleLuminance(InputFrame frame) {
    if (frame.image.planes.isEmpty) {
      return const _LuminanceSample(average: 255.0, darkPixelRatio: 0.0);
    }

    final yPlane = frame.image.planes.first.bytes;

    if (yPlane.isEmpty) {
      return const _LuminanceSample(average: 255.0, darkPixelRatio: 0.0);
    }

    final step = math.max(1, yPlane.length ~/ sampleCount);

    int sum = 0;
    int count = 0;
    int darkPixels = 0;

    for (int i = 0; i < yPlane.length; i += step) {
      final value = yPlane[i];

      sum += value;
      count++;

      if (value <= darkPixelLuminance) {
        darkPixels++;
      }

      if (count >= sampleCount) break;
    }

    if (count == 0) {
      return const _LuminanceSample(average: 255.0, darkPixelRatio: 0.0);
    }

    return _LuminanceSample(
      average: sum / count,
      darkPixelRatio: darkPixels / count,
    );
  }

  Future<void> _setTorch({
    required CameraSessionController session,
    required bool enabled,
    bool force = false,
  }) async {
    if (_changing && !force) return;

    if (_torchOn == enabled && !force) {
      return;
    }

    _changing = true;

    try {
      final cameraController = session.rawController();

      if (cameraController == null) {
        if (!enabled) {
          _markTorchState(false);
        }
        return;
      }

      if (!cameraController.value.isInitialized) {
        if (!enabled) {
          _markTorchState(false);
        }
        return;
      }

      await cameraController.setFlashMode(
        enabled ? FlashMode.torch : FlashMode.off,
      );

      _markTorchState(enabled);
    } catch (_) {
      if (!enabled) {
        _markTorchState(false);
      }
    } finally {
      _changing = false;
    }
  }

  void _markTorchState(bool enabled) {
    if (_torchOn != enabled) {
      _lastTorchChangedAt = DateTime.now();
    }

    _torchOn = enabled;
    _darkFrames = 0;
    _brightFrames = 0;
  }
}

class _LuminanceSample {
  final double average;
  final double darkPixelRatio;

  const _LuminanceSample({required this.average, required this.darkPixelRatio});
}
