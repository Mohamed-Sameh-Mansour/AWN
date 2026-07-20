import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

void cocoObstacleInferenceWorkerMain(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  final worker = _CocoObstacleInferenceWorker(mainSendPort);

  mainSendPort.send(receivePort.sendPort);
  receivePort.listen(worker.handleMessage);
}

class _CocoObstacleInferenceWorker {
  _CocoObstacleInferenceWorker(this._mainSendPort);

  final SendPort _mainSendPort;

  Interpreter? _interpreter;
  List<List<int>> _outputShapes = [];

  int _inputWidth = 320;
  int _inputHeight = 320;
  double _confidenceThreshold = 0.25;
  bool _ready = false;

  void handleMessage(dynamic message) async {
    if (message is! Map) return;

    final id = message['id'];

    try {
      final type = message['type'];

      if (type == 'init') {
        await _handleInit(message);
        _sendOk(id, {
          'inputWidth': _inputWidth,
          'inputHeight': _inputHeight,
          'outputShapes': _outputShapes,
        });
        return;
      }

      if (type == 'detect') {
        final detections = _handleDetect(message);
        _sendOk(id, {'detections': detections});
        return;
      }

      if (type == 'dispose') {
        _dispose();
        _sendOk(id, {});
        return;
      }

      throw StateError('Unknown COCO worker message type: $type');
    } catch (error) {
      _sendError(id, error.toString());
    }
  }

  Future<void> _handleInit(Map message) async {
    final modelTransfer = message['modelBytes'] as TransferableTypedData;
    final modelBytes = modelTransfer.materialize().asUint8List();

    _confidenceThreshold =
        (message['confidenceThreshold'] as num?)?.toDouble() ?? 0.25;

    _interpreter = Interpreter.fromBuffer(modelBytes);

    final interpreter = _interpreter;

    if (interpreter == null) {
      throw StateError('COCO interpreter did not load.');
    }

    final inputShape = interpreter.getInputTensor(0).shape;

    if (inputShape.length != 4) {
      throw StateError('Unexpected COCO input shape: $inputShape');
    }

    _inputHeight = inputShape[1];
    _inputWidth = inputShape[2];

    _outputShapes = interpreter
        .getOutputTensors()
        .map((tensor) => List<int>.from(tensor.shape))
        .toList();

    if (_outputShapes.length < 4) {
      throw StateError('COCO model must have 4 outputs. Found $_outputShapes');
    }

    _ready = true;
  }

  List<Map<String, dynamic>> _handleDetect(Map message) {
    final interpreter = _interpreter;

    if (!_ready || interpreter == null) return [];

    final width = message['width'] as int;
    final height = message['height'] as int;
    final rotationDegrees = message['rotationDegrees'] as int;
    final planesMessage = message['planes'] as List;

    final planes = planesMessage.map((plane) {
      final planeMap = plane as Map;
      final transfer = planeMap['bytes'] as TransferableTypedData;

      return _PlaneData(
        bytes: transfer.materialize().asUint8List(),
        bytesPerRow: planeMap['bytesPerRow'] as int,
        bytesPerPixel: (planeMap['bytesPerPixel'] as int?) ?? 1,
      );
    }).toList();

    final rgbImage = _convertYuv420ToImage(
      width: width,
      height: height,
      planes: planes,
    );

    final rotatedImage = _rotateForModel(rgbImage, rotationDegrees);
    final input = _imageToModelInput(rotatedImage);

    final outputs = <int, Object>{};

    for (var i = 0; i < _outputShapes.length; i++) {
      outputs[i] = _makeZeroTensor(_outputShapes[i]);
    }

    interpreter.runForMultipleInputs([input], outputs);

    return _parseOutputs(outputs);
  }

  List<Map<String, dynamic>> _parseOutputs(Map<int, Object> outputs) {
    final boxes = outputs[0] as List;
    final outputOne = _readOutputVector(outputs[1]);
    final outputTwo = _readOutputVector(outputs[2]);
    final countVector = _readOutputVector(outputs[3]);

    final resolved = _resolveClassesAndScores(
      outputOne: outputOne,
      outputTwo: outputTwo,
    );

    final classes = resolved.classes;
    final scores = resolved.scores;

    final rawCount = countVector.isEmpty ? 25 : countVector.first.round();
    final safeCount = rawCount <= 0 ? 25 : min(rawCount, 25);

    final detections = <Map<String, dynamic>>[];

    for (var i = 0; i < safeCount; i++) {
      if (i >= classes.length || i >= scores.length) break;

      final score = scores[i];

      if (score < _confidenceThreshold) continue;

      final box = ((boxes.first as List)[i] as List)
          .map((value) => (value as num).toDouble())
          .toList();

      if (box.length < 4) continue;

      final top = _clamp01(box[0]);
      final left = _clamp01(box[1]);
      final bottom = _clamp01(box[2]);
      final right = _clamp01(box[3]);

      if (right <= left || bottom <= top) continue;

      detections.add({
        'classIndex': classes[i].round(),
        'score': score,
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
      });
    }

    return detections;
  }

  _ResolvedOutputs _resolveClassesAndScores({
    required List<double> outputOne,
    required List<double> outputTwo,
  }) {
    final outputOneMax = _maxValue(outputOne);
    final outputTwoMax = _maxValue(outputTwo);

    final outputOneLooksLikeClasses = outputOneMax > 1.5;
    final outputTwoLooksLikeClasses = outputTwoMax > 1.5;

    if (outputOneLooksLikeClasses && !outputTwoLooksLikeClasses) {
      return _ResolvedOutputs(classes: outputOne, scores: outputTwo);
    }

    if (outputTwoLooksLikeClasses && !outputOneLooksLikeClasses) {
      return _ResolvedOutputs(classes: outputTwo, scores: outputOne);
    }

    return _ResolvedOutputs(classes: outputOne, scores: outputTwo);
  }

  List<double> _readOutputVector(Object? output) {
    if (output is! List || output.isEmpty) return [];

    final first = output.first;

    if (first is List) {
      return first.map((value) => (value as num).toDouble()).toList();
    }

    return output.map((value) => (value as num).toDouble()).toList();
  }

  Object _makeZeroTensor(List<int> shape) {
    if (shape.length == 1) {
      return List<double>.filled(shape[0], 0.0);
    }

    return List.generate(shape[0], (_) => _makeZeroTensor(shape.sublist(1)));
  }

  List<List<List<List<int>>>> _imageToModelInput(img.Image image) {
    final resized = img.copyResize(
      image,
      width: _inputWidth,
      height: _inputHeight,
      interpolation: img.Interpolation.linear,
    );

    return [
      List.generate(_inputHeight, (y) {
        return List.generate(_inputWidth, (x) {
          final pixel = resized.getPixel(x, y);

          return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
        });
      }),
    ];
  }

  img.Image _convertYuv420ToImage({
    required int width,
    required int height,
    required List<_PlaneData> planes,
  }) {
    final planeY = planes[0];
    final planeU = planes[1];
    final planeV = planes[2];

    final out = img.Image(width: width, height: height);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final yIndex = y * planeY.bytesPerRow + x;

        final uvRow = y >> 1;
        final uvCol = x >> 1;

        final uIndex =
            uvRow * planeU.bytesPerRow + uvCol * planeU.bytesPerPixel;
        final vIndex =
            uvRow * planeV.bytesPerRow + uvCol * planeV.bytesPerPixel;

        final yValue = planeY.bytes[yIndex];
        final uValue = planeU.bytes[uIndex];
        final vValue = planeV.bytes[vIndex];

        var r = (yValue + 1.402 * (vValue - 128)).round();
        var g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
            .round();
        var b = (yValue + 1.772 * (uValue - 128)).round();

        r = max(0, min(255, r));
        g = max(0, min(255, g));
        b = max(0, min(255, b));

        out.setPixelRgb(x, y, r, g, b);
      }
    }

    return out;
  }

  img.Image _rotateForModel(img.Image image, int rotationDegrees) {
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

  double _clamp01(double value) {
    if (value < 0.0) return 0.0;
    if (value > 1.0) return 1.0;
    return value;
  }

  double _maxValue(List<double> values) {
    var maxValue = 0.0;

    for (final value in values) {
      if (value > maxValue) {
        maxValue = value;
      }
    }

    return maxValue;
  }

  void _sendOk(dynamic id, Map<String, dynamic> data) {
    _mainSendPort.send({'id': id, 'ok': true, ...data});
  }

  void _sendError(dynamic id, String error) {
    _mainSendPort.send({'id': id, 'ok': false, 'error': error});
  }

  void _dispose() {
    _ready = false;
    _interpreter?.close();
    _interpreter = null;
  }
}

class _PlaneData {
  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;

  const _PlaneData({
    required this.bytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });
}

class _ResolvedOutputs {
  final List<double> classes;
  final List<double> scores;

  const _ResolvedOutputs({required this.classes, required this.scores});
}
