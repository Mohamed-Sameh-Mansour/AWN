import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class CameraUtils {
  const CameraUtils._();

  static img.Image convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final planeY = image.planes[0];
    final planeU = image.planes[1];
    final planeV = image.planes[2];

    final bytesY = planeY.bytes;
    final bytesU = planeU.bytes;
    final bytesV = planeV.bytes;

    final int strideY = planeY.bytesPerRow;
    final int strideU = planeU.bytesPerRow;
    final int strideV = planeV.bytesPerRow;

    final int pixelStrideU = planeU.bytesPerPixel ?? 1;
    final int pixelStrideV = planeV.bytesPerPixel ?? 1;

    final out = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * strideY + x;

        final int uvRow = y >> 1;
        final int uvCol = x >> 1;

        final int uIndex = uvRow * strideU + uvCol * pixelStrideU;
        final int vIndex = uvRow * strideV + uvCol * pixelStrideV;

        final int yValue = bytesY[yIndex];
        final int uValue = bytesU[uIndex];
        final int vValue = bytesV[vIndex];

        int r = (yValue + 1.402 * (vValue - 128)).round();
        int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
            .round();
        int b = (yValue + 1.772 * (uValue - 128)).round();

        r = max(0, min(255, r));
        g = max(0, min(255, g));
        b = max(0, min(255, b));

        out.setPixelRgb(x, y, r, g, b);
      }
    }

    return out;
  }

  static img.Image rotateForModel(img.Image image, int rotationDegrees) {
    final normalized = rotationDegrees % 360;

    if (normalized == 90) {
      return img.copyRotate(image, angle: 90);
    }

    if (normalized == 180) {
      return img.copyRotate(image, angle: 180);
    }

    if (normalized == 270) {
      return img.copyRotate(image, angle: 270);
    }

    return image;
  }

  static double iouRect(Rect a, Rect b) {
    final interLeft = max(a.left, b.left);
    final interTop = max(a.top, b.top);
    final interRight = min(a.right, b.right);
    final interBottom = min(a.bottom, b.bottom);

    final interW = max(0.0, interRight - interLeft);
    final interH = max(0.0, interBottom - interTop);
    final interArea = interW * interH;

    final areaA = max(0.0, a.width) * max(0.0, a.height);
    final areaB = max(0.0, b.width) * max(0.0, b.height);

    final union = areaA + areaB - interArea;

    if (union <= 0) return 0.0;

    return interArea / union;
  }
}
