import 'dart:ui';

import 'package:camera/camera.dart';
import 'input_frame.dart';

typedef FrameCallback = void Function(InputFrame frame);

/// Shared camera wrapper. One instance per feature session (per your preference).
class AppCameraController {
  CameraController? _controller;
  ResolutionPreset? _activeResolutionPreset;

  CameraController? get controller => _controller;
  ResolutionPreset? get activeResolutionPreset => _activeResolutionPreset;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// Initialize the camera.
  ///
  /// It tries [resolutionPreset] first. If the device cannot initialize the
  /// camera with that preset, it automatically tries [fallbackResolutionPresets]
  /// in order. This keeps stronger devices on medium/high quality while weaker
  /// devices can safely drop to low quality instead of crashing the feature.
  Future<void> initialize({
    CameraLensDirection lensDirection = CameraLensDirection.back,
    ResolutionPreset resolutionPreset = ResolutionPreset.medium,
    List<ResolutionPreset> fallbackResolutionPresets = const [],
  }) async {
    await dispose();

    final cameras = await availableCameras();

    if (cameras.isEmpty) {
      throw StateError('No cameras available on this device');
    }

    final selected = cameras.firstWhere(
      (c) => c.lensDirection == lensDirection,
      orElse: () => cameras.first,
    );

    final presetsToTry = <ResolutionPreset>[
      resolutionPreset,
      ...fallbackResolutionPresets,
    ];

    final uniquePresetsToTry = <ResolutionPreset>[];

    for (final preset in presetsToTry) {
      if (!uniquePresetsToTry.contains(preset)) {
        uniquePresetsToTry.add(preset);
      }
    }

    Object? lastError;

    for (final preset in uniquePresetsToTry) {
      CameraController? controller;

      try {
        controller = CameraController(
          selected,
          preset,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.yuv420,
        );

        await controller.initialize();

        _controller = controller;
        _activeResolutionPreset = preset;
        return;
      } catch (error) {
        lastError = error;

        try {
          await controller?.dispose();
        } catch (_) {}
      }
    }

    _controller = null;
    _activeResolutionPreset = null;

    final presetsText = uniquePresetsToTry
        .map((preset) => preset.name)
        .join(', ');

    throw StateError(
      'Unable to initialize camera with presets: $presetsText. Last error: $lastError',
    );
  }

  /// Start streaming frames to [onFrame].
  Future<void> startImageStream({required FrameCallback onFrame}) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw StateError('Camera not initialized');
    }
    if (controller.value.isStreamingImages) return;

    await controller.startImageStream((CameraImage image) {
      final rotation = controller.description.sensorOrientation;
      final size = controller.value.previewSize;
      onFrame(
        InputFrame(
          image: image,
          rotationDegrees: rotation,
          previewSize: size != null
              ? Size(size.width, size.height)
              : const Size(0, 0),
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  Future<void> stopImageStream() async {
    final controller = _controller;
    if (controller == null) return;
    if (!controller.value.isStreamingImages) return;
    await controller.stopImageStream();
  }

  Future<void> dispose() async {
    await stopImageStream();
    await _controller?.dispose();
    _controller = null;
    _activeResolutionPreset = null;
  }
}
