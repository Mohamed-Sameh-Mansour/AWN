import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Pure camera preview widget (no business logic).
class CameraPreviewView extends StatelessWidget {
  final CameraController controller;

  const CameraPreviewView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CameraPreview(controller),
    );
  }
}
