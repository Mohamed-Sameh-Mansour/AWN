import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'app_camera_controller.dart';
import 'camera_preview_view.dart';
import 'input_frame.dart';

typedef OnFrame = Future<void> Function(InputFrame frame);

class CameraSessionController {
  final Future<XFile?> Function({bool resumeStream}) takePicture;
  final Future<void> Function() stopStream;
  final Future<void> Function() startStream;
  final CameraController? Function() rawController;

  CameraSessionController({
    required this.takePicture,
    required this.stopStream,
    required this.startStream,
    required this.rawController,
  });
}

class CameraSession extends StatefulWidget {
  final OnFrame onFrame;
  final Widget Function(BuildContext context, Widget preview) builder;

  final CameraLensDirection lensDirection;
  final ResolutionPreset resolutionPreset;
  final List<ResolutionPreset> fallbackResolutionPresets;

  final Duration? minFrameInterval;

  final void Function(CameraController controller)? onCameraReady;

  final void Function(CameraSessionController session)? onSessionReady;

  const CameraSession({
    super.key,
    required this.onFrame,
    required this.builder,
    this.lensDirection = CameraLensDirection.back,
    this.resolutionPreset = ResolutionPreset.medium,
    this.fallbackResolutionPresets = const [ResolutionPreset.low],
    this.minFrameInterval,
    this.onCameraReady,
    this.onSessionReady,
  });

  @override
  State<CameraSession> createState() => _CameraSessionState();
}

class _CameraSessionState extends State<CameraSession> {
  final AppCameraController _camera = AppCameraController();

  bool _busy = false;
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);

  bool _streaming = false;
  bool _initialized = false;
  bool _disposed = false;

  Object? _initializationError;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      await _camera.initialize(
        lensDirection: widget.lensDirection,
        resolutionPreset: widget.resolutionPreset,
        fallbackResolutionPresets: widget.fallbackResolutionPresets,
      );
    } catch (error) {
      if (!mounted || _disposed) return;

      _initializationError = error;
      _initialized = false;

      setState(() {});

      return;
    }

    if (!mounted || _disposed) return;

    _initializationError = null;
    _initialized = true;

    setState(() {});

    final controller = _camera.controller;

    if (controller != null) {
      try {
        widget.onCameraReady?.call(controller);
      } catch (_) {
        // Keep the camera session alive even if a feature callback fails.
      }
    }

    try {
      widget.onSessionReady?.call(
        CameraSessionController(
          takePicture: ({bool resumeStream = false}) async {
            if (_disposed) return null;

            final c = _camera.controller;

            if (c == null || !c.value.isInitialized) return null;

            if (_streaming) {
              try {
                await _camera.stopImageStream();
              } catch (_) {
                // Ignore stream stop failures to avoid crashing the feature.
              }

              _streaming = false;
            }

            try {
              final file = await c.takePicture();

              if (resumeStream && !_disposed) {
                await _safeStartStream();
              }

              return file;
            } catch (_) {
              if (resumeStream && !_disposed) {
                await _safeStartStream();
              }

              return null;
            }
          },
          stopStream: () async {
            if (_disposed) return;
            if (!_streaming) return;

            try {
              await _camera.stopImageStream();
            } catch (_) {
              // Ignore stream stop failures to keep cleanup safe.
            }

            _streaming = false;
          },
          startStream: () async {
            if (_disposed) return;
            await _safeStartStream();
          },
          rawController: () {
            if (_disposed) return null;
            return _camera.controller;
          },
        ),
      );
    } catch (_) {
      // A broken session-ready callback should not crash the camera screen.
    }

    await _safeStartStream();
  }

  Future<void> _safeStartStream() async {
    if (_disposed) return;

    final controller = _camera.controller;

    if (controller == null || !controller.value.isInitialized) return;
    if (_streaming || controller.value.isStreamingImages) {
      _streaming = true;
      return;
    }

    try {
      await _camera.startImageStream(onFrame: _handleFrame);

      if (!_disposed) {
        _streaming = true;
      }
    } catch (_) {
      _streaming = false;
    }
  }

  void _handleFrame(InputFrame frame) {
    if (_disposed) return;

    final interval = widget.minFrameInterval;

    if (interval != null) {
      final now = DateTime.now();

      if (now.difference(_lastFrameTime) < interval) return;

      _lastFrameTime = now;
    }

    if (_busy) return;

    _busy = true;

    unawaited(_processFrame(frame));
  }

  Future<void> _processFrame(InputFrame frame) async {
    try {
      await widget.onFrame(frame);
    } catch (_) {
      // Ignore single-frame processing errors.
      // This prevents one bad frame/API/model error from crashing the camera session.
    } finally {
      _busy = false;
    }
  }

  Future<void> _safeDisposeCamera() async {
    try {
      await _camera.dispose();
    } catch (_) {
      // Dispose must never crash while leaving a camera feature.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _busy = false;
    _streaming = false;

    unawaited(_safeDisposeCamera());

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _camera.controller;

    Widget preview;

    if (_initializationError != null) {
      preview = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Camera is not available right now.\nPlease close this screen and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else if (_initialized &&
        controller != null &&
        controller.value.isInitialized) {
      preview = CameraPreviewView(controller: controller);
    } else {
      preview = const Center(child: CircularProgressIndicator());
    }

    return widget.builder(context, preview);
  }
}
