import 'package:camera/camera.dart';
import 'dart:ui';

/// A unified frame object passed from the shared camera layer to a feature handler.
class InputFrame {
  final CameraImage image;
  final int rotationDegrees; // 0, 90, 180, 270
  final Size previewSize;
  final DateTime timestamp;

  const InputFrame({
    required this.image,
    required this.rotationDegrees,
    required this.previewSize,
    required this.timestamp,
  });
}
