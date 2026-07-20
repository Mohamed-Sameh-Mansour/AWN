import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

void obstacleInferenceWorkerMain(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  final worker = _ObstacleInferenceWorker(mainSendPort);

  mainSendPort.send(receivePort.sendPort);

  receivePort.listen(worker.handleMessage);
}

class _ObstacleInferenceWorker {
  _ObstacleInferenceWorker(this._mainSendPort);

  final SendPort _mainSendPort;

  Interpreter? _interpreter;
  List<String> _labels = [];
  List<List<int>> _outputShapes = [];

  int _inputWidth = 640;
  int _inputHeight = 640;
  int _numClasses = 12;

  double _confidenceThreshold = 0.20;
  double _iouThreshold = 0.45;

  bool _ready = false;

  void handleMessage(dynamic message) async {
    if (message is! Map) return;

    final id = message['id'];

    try {
      final type = message['type'];

      if (type == 'init') {
        await _handleInit(message);
        _sendOk(id, {
          'outputShapes': _outputShapes,
          'inputWidth': _inputWidth,
          'inputHeight': _inputHeight,
        });
        return;
      }

      if (type == 'detect') {
        final result = _handleDetect(message);
        _sendOk(id, {'detections': result});
        return;
      }

      if (type == 'dispose') {
        _dispose();
        _sendOk(id, {});
        return;
      }

      throw StateError('Unknown worker message type: $type');
    } catch (error) {
      _sendError(id, error.toString());
    }
  }

  Future<void> _handleInit(Map message) async {
    final modelTransfer = message['modelBytes'] as TransferableTypedData;
    final modelBytes = modelTransfer.materialize().asUint8List();

    _labels = (message['labels'] as List).map((e) => e.toString()).toList();

    _confidenceThreshold =
        (message['confidenceThreshold'] as num?)?.toDouble() ?? 0.20;

    _iouThreshold = (message['iouThreshold'] as num?)?.toDouble() ?? 0.45;

    _numClasses = (message['numClasses'] as int?) ?? _labels.length;

    _interpreter = Interpreter.fromBuffer(modelBytes);

    final interpreter = _interpreter;

    if (interpreter == null) {
      throw StateError('Obstacle interpreter did not load in worker.');
    }

    final inputShape = interpreter.getInputTensor(0).shape;

    if (inputShape.length != 4) {
      throw StateError('Unexpected obstacle input shape: $inputShape');
    }

    _inputHeight = inputShape[1];
    _inputWidth = inputShape[2];

    if (_inputWidth <= 0 || _inputHeight <= 0) {
      throw StateError('Invalid obstacle input shape: $inputShape');
    }

    _outputShapes = interpreter
        .getOutputTensors()
        .map((tensor) => List<int>.from(tensor.shape))
        .toList();

    if (_outputShapes.isEmpty) {
      throw StateError('Obstacle model has no output tensors.');
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
    final input = _imageToMatrix(rotatedImage);

    final detections = <_WorkerDetection>[];

    if (_outputShapes.length == 1) {
      final shape = _outputShapes.first;
      final output = _makeZeroTensor(shape);

      interpreter.run(input, output);

      detections.addAll(_parseSingleOutput(output, shape));
    } else {
      final outputs = <int, Object>{};

      for (int i = 0; i < _outputShapes.length; i++) {
        outputs[i] = _makeZeroTensor(_outputShapes[i]);
      }

      interpreter.runForMultipleInputs([input], outputs);

      detections.addAll(_parseMultipleOutputs(outputs, _outputShapes));
    }

    final finalDetections = _applyClassWiseNms(detections);

    return finalDetections.map((detection) => detection.toJson()).toList();
  }

  img.Image _convertYuv420ToImage({
    required int width,
    required int height,
    required List<_PlaneData> planes,
  }) {
    final planeY = planes[0];
    final planeU = planes[1];
    final planeV = planes[2];

    final bytesY = planeY.bytes;
    final bytesU = planeU.bytes;
    final bytesV = planeV.bytes;

    final strideY = planeY.bytesPerRow;
    final strideU = planeU.bytesPerRow;
    final strideV = planeV.bytesPerRow;

    final pixelStrideU = planeU.bytesPerPixel;
    final pixelStrideV = planeV.bytesPerPixel;

    final out = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * strideY + x;

        final uvRow = y >> 1;
        final uvCol = x >> 1;

        final uIndex = uvRow * strideU + uvCol * pixelStrideU;
        final vIndex = uvRow * strideV + uvCol * pixelStrideV;

        final yValue = bytesY[yIndex];
        final uValue = bytesU[uIndex];
        final vValue = bytesV[vIndex];

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

  List<List<List<List<double>>>> _imageToMatrix(img.Image image) {
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

          return <double>[
            pixel.r.toDouble() / 255.0,
            pixel.g.toDouble() / 255.0,
            pixel.b.toDouble() / 255.0,
          ];
        });
      }),
    ];
  }

  Object _makeZeroTensor(List<int> shape) {
    if (shape.isEmpty) {
      return 0.0;
    }

    if (shape.length == 1) {
      return List<double>.filled(shape[0], 0.0);
    }

    return List.generate(shape[0], (_) => _makeZeroTensor(shape.sublist(1)));
  }

  List<_WorkerDetection> _parseSingleOutput(dynamic output, List<int> shape) {
    if (shape.length != 3) return [];

    final dim1 = shape[1];
    final dim2 = shape[2];

    final oldOutputChannels = 4 + _numClasses;

    if (dim1 == oldOutputChannels && dim2 > 100) {
      return _parseOldYoloChannelsFirst(output, dim2);
    }

    if (dim2 == oldOutputChannels && dim1 > 100) {
      return _parseOldYoloRows(output, dim1);
    }

    if (dim2 >= 6 && dim1 <= 1000) {
      return _parseNmsRows(output, dim1, dim2);
    }

    if (dim1 >= 6 && dim2 <= 1000) {
      return _parseNmsChannelsFirst(output, dim1, dim2);
    }

    return [];
  }

  List<_WorkerDetection> _parseOldYoloChannelsFirst(
    dynamic output,
    int anchors,
  ) {
    final detections = <_WorkerDetection>[];

    for (int anchor = 0; anchor < anchors; anchor++) {
      double bestScore = -1.0;
      int bestClassId = -1;

      for (int classIndex = 0; classIndex < _numClasses; classIndex++) {
        final score = _toDouble(output[0][4 + classIndex][anchor]);

        if (score > bestScore) {
          bestScore = score;
          bestClassId = classIndex;
        }
      }

      if (bestClassId < 0) continue;
      if (bestScore < _confidenceThreshold) continue;

      final cxRaw = _toDouble(output[0][0][anchor]);
      final cyRaw = _toDouble(output[0][1][anchor]);
      final wRaw = _toDouble(output[0][2][anchor]);
      final hRaw = _toDouble(output[0][3][anchor]);

      final box = _centerBoxToNormalizedBox(
        cxRaw: cxRaw,
        cyRaw: cyRaw,
        wRaw: wRaw,
        hRaw: hRaw,
      );

      if (box == null) continue;

      detections.add(
        _WorkerDetection(classId: bestClassId, confidence: bestScore, box: box),
      );
    }

    return detections;
  }

  List<_WorkerDetection> _parseOldYoloRows(dynamic output, int rows) {
    final detections = <_WorkerDetection>[];

    for (int rowIndex = 0; rowIndex < rows; rowIndex++) {
      final row = output[0][rowIndex];

      double bestScore = -1.0;
      int bestClassId = -1;

      for (int classIndex = 0; classIndex < _numClasses; classIndex++) {
        final score = _toDouble(row[4 + classIndex]);

        if (score > bestScore) {
          bestScore = score;
          bestClassId = classIndex;
        }
      }

      if (bestClassId < 0) continue;
      if (bestScore < _confidenceThreshold) continue;

      final box = _centerBoxToNormalizedBox(
        cxRaw: _toDouble(row[0]),
        cyRaw: _toDouble(row[1]),
        wRaw: _toDouble(row[2]),
        hRaw: _toDouble(row[3]),
      );

      if (box == null) continue;

      detections.add(
        _WorkerDetection(classId: bestClassId, confidence: bestScore, box: box),
      );
    }

    return detections;
  }

  List<_WorkerDetection> _parseNmsRows(dynamic output, int rows, int columns) {
    final detections = <_WorkerDetection>[];

    for (int rowIndex = 0; rowIndex < rows; rowIndex++) {
      final values = <double>[];

      for (int column = 0; column < columns; column++) {
        values.add(_toDouble(output[0][rowIndex][column]));
      }

      final detection = _parseNmsValues(values);

      if (detection != null) detections.add(detection);
    }

    return detections;
  }

  List<_WorkerDetection> _parseNmsChannelsFirst(
    dynamic output,
    int channels,
    int rows,
  ) {
    final detections = <_WorkerDetection>[];

    for (int rowIndex = 0; rowIndex < rows; rowIndex++) {
      final values = <double>[];

      for (int channel = 0; channel < channels; channel++) {
        values.add(_toDouble(output[0][channel][rowIndex]));
      }

      final detection = _parseNmsValues(values);

      if (detection != null) detections.add(detection);
    }

    return detections;
  }

  _WorkerDetection? _parseNmsValues(List<double> values) {
    if (values.length < 6) return null;

    final scoreAndClass = _extractScoreAndClass(values);

    if (scoreAndClass == null) return null;

    final confidence = scoreAndClass.score;
    final classId = scoreAndClass.classId;

    if (confidence < _confidenceThreshold) return null;
    if (!_isValidClassId(classId)) return null;

    final x1 = values[0];
    final y1 = values[1];
    final x2 = values[2];
    final y2 = values[3];

    _Box? box = _cornersBoxToNormalizedBox(
      x1Raw: x1,
      y1Raw: y1,
      x2Raw: x2,
      y2Raw: y2,
    );

    box ??= _centerBoxToNormalizedBox(cxRaw: x1, cyRaw: y1, wRaw: x2, hRaw: y2);

    if (box == null) return null;

    return _WorkerDetection(classId: classId, confidence: confidence, box: box);
  }

  _NmsScoreClass? _extractScoreAndClass(List<double> values) {
    final optionAConfidence = values[4];
    final optionAClassId = values[5].round();

    final optionAValid =
        _isValidConfidence(optionAConfidence) &&
        _isValidClassId(optionAClassId);

    if (optionAValid) {
      return _NmsScoreClass(score: optionAConfidence, classId: optionAClassId);
    }

    final optionBClassId = values[4].round();
    final optionBConfidence = values[5];

    final optionBValid =
        _isValidConfidence(optionBConfidence) &&
        _isValidClassId(optionBClassId);

    if (optionBValid) {
      return _NmsScoreClass(score: optionBConfidence, classId: optionBClassId);
    }

    return null;
  }

  List<_WorkerDetection> _parseMultipleOutputs(
    Map<int, Object> outputs,
    List<List<int>> shapes,
  ) {
    final boxesIndex = _findBoxesOutputIndex(shapes);

    if (boxesIndex == null) return [];

    final boxesShape = shapes[boxesIndex];

    if (boxesShape.length != 3) return [];

    final count = boxesShape[1];
    final boxesOutput = outputs[boxesIndex];

    if (boxesOutput == null) return [];

    int? scoresIndex;
    int? classesIndex;
    int? numIndex;

    for (int i = 0; i < shapes.length; i++) {
      if (i == boxesIndex) continue;

      final shape = shapes[i];

      if (shape.length == 1 && shape[0] == 1) {
        numIndex = i;
        continue;
      }

      if (shape.length == 2 && shape[0] == 1 && shape[1] == count) {
        final output = outputs[i];

        if (output == null) continue;

        final sampleValues = <double>[];
        final sampleCount = min(count, 10);

        for (int j = 0; j < sampleCount; j++) {
          sampleValues.add(_toDouble((output as dynamic)[0][j]));
        }

        final looksLikeClassIds = sampleValues.every((value) {
          final rounded = value.round();

          return _isValidClassId(rounded) && (value - rounded).abs() < 0.01;
        });

        if (looksLikeClassIds) {
          classesIndex = i;
        } else {
          scoresIndex = i;
        }
      }
    }

    if (scoresIndex == null || classesIndex == null) return [];

    int activeCount = count;

    if (numIndex != null) {
      final numOutput = outputs[numIndex];

      if (numOutput != null) {
        final detectedCount = _toDouble((numOutput as dynamic)[0]).round();

        if (detectedCount > 0 && detectedCount <= count) {
          activeCount = detectedCount;
        }
      }
    }

    final scoresOutput = outputs[scoresIndex];
    final classesOutput = outputs[classesIndex];

    if (scoresOutput == null || classesOutput == null) return [];

    final detections = <_WorkerDetection>[];

    for (int i = 0; i < activeCount; i++) {
      final confidence = _toDouble((scoresOutput as dynamic)[0][i]);
      final classId = _toDouble((classesOutput as dynamic)[0][i]).round();

      if (confidence < _confidenceThreshold) continue;
      if (!_isValidClassId(classId)) continue;

      final boxValues = <double>[
        _toDouble((boxesOutput as dynamic)[0][i][0]),
        _toDouble((boxesOutput as dynamic)[0][i][1]),
        _toDouble((boxesOutput as dynamic)[0][i][2]),
        _toDouble((boxesOutput as dynamic)[0][i][3]),
      ];

      _Box? box = _cornersBoxToNormalizedBox(
        x1Raw: boxValues[0],
        y1Raw: boxValues[1],
        x2Raw: boxValues[2],
        y2Raw: boxValues[3],
      );

      box ??= _cornersBoxToNormalizedBox(
        x1Raw: boxValues[1],
        y1Raw: boxValues[0],
        x2Raw: boxValues[3],
        y2Raw: boxValues[2],
      );

      if (box == null) continue;

      detections.add(
        _WorkerDetection(classId: classId, confidence: confidence, box: box),
      );
    }

    return detections;
  }

  int? _findBoxesOutputIndex(List<List<int>> shapes) {
    for (int i = 0; i < shapes.length; i++) {
      final shape = shapes[i];

      if (shape.length == 3 && shape[0] == 1 && shape[2] == 4) {
        return i;
      }
    }

    return null;
  }

  _Box? _centerBoxToNormalizedBox({
    required double cxRaw,
    required double cyRaw,
    required double wRaw,
    required double hRaw,
  }) {
    if (!_isFinitePositiveBox(wRaw, hRaw)) return null;

    final looksNormalized =
        cxRaw <= 1.5 && cyRaw <= 1.5 && wRaw <= 1.5 && hRaw <= 1.5;

    final cx = looksNormalized ? cxRaw : cxRaw / _inputWidth;
    final cy = looksNormalized ? cyRaw : cyRaw / _inputHeight;
    final w = looksNormalized ? wRaw : wRaw / _inputWidth;
    final h = looksNormalized ? hRaw : hRaw / _inputHeight;

    final left = _clamp01(cx - w / 2);
    final top = _clamp01(cy - h / 2);
    final right = _clamp01(cx + w / 2);
    final bottom = _clamp01(cy + h / 2);

    return _validateBox(
      _Box(left: left, top: top, right: right, bottom: bottom),
    );
  }

  _Box? _cornersBoxToNormalizedBox({
    required double x1Raw,
    required double y1Raw,
    required double x2Raw,
    required double y2Raw,
  }) {
    if (x1Raw.isNaN || y1Raw.isNaN || x2Raw.isNaN || y2Raw.isNaN) {
      return null;
    }

    if (x1Raw.isInfinite ||
        y1Raw.isInfinite ||
        x2Raw.isInfinite ||
        y2Raw.isInfinite) {
      return null;
    }

    final looksNormalized =
        x1Raw <= 1.5 && y1Raw <= 1.5 && x2Raw <= 1.5 && y2Raw <= 1.5;

    final x1 = looksNormalized ? x1Raw : x1Raw / _inputWidth;
    final y1 = looksNormalized ? y1Raw : y1Raw / _inputHeight;
    final x2 = looksNormalized ? x2Raw : x2Raw / _inputWidth;
    final y2 = looksNormalized ? y2Raw : y2Raw / _inputHeight;

    final left = _clamp01(min(x1, x2));
    final top = _clamp01(min(y1, y2));
    final right = _clamp01(max(x1, x2));
    final bottom = _clamp01(max(y1, y2));

    return _validateBox(
      _Box(left: left, top: top, right: right, bottom: bottom),
    );
  }

  _Box? _validateBox(_Box box) {
    if (box.right <= box.left || box.bottom <= box.top) return null;

    if (box.width < 0.004 || box.height < 0.004) return null;

    final looksLikeFullScreenWrongBox =
        box.width > 0.98 && box.height > 0.98 && box.area >= 0.98;

    if (looksLikeFullScreenWrongBox) return null;

    return box;
  }

  bool _isFinitePositiveBox(double width, double height) {
    if (width.isNaN || height.isNaN) return false;
    if (width.isInfinite || height.isInfinite) return false;
    if (width <= 0 || height <= 0) return false;

    return true;
  }

  List<_WorkerDetection> _applyClassWiseNms(List<_WorkerDetection> detections) {
    final output = <_WorkerDetection>[];
    final grouped = <int, List<_WorkerDetection>>{};

    for (final detection in detections) {
      grouped.putIfAbsent(detection.classId, () => []).add(detection);
    }

    for (final sameClass in grouped.values) {
      sameClass.sort((a, b) => b.confidence.compareTo(a.confidence));

      final kept = <_WorkerDetection>[];

      for (final candidate in sameClass) {
        bool shouldKeep = true;

        for (final existing in kept) {
          final iou = _iou(candidate.box, existing.box);

          if (iou > _iouThreshold) {
            shouldKeep = false;
            break;
          }
        }

        if (shouldKeep) kept.add(candidate);
      }

      output.addAll(kept);
    }

    output.sort((a, b) => b.confidence.compareTo(a.confidence));

    return output;
  }

  double _iou(_Box a, _Box b) {
    final intersectionLeft = max(a.left, b.left);
    final intersectionTop = max(a.top, b.top);
    final intersectionRight = min(a.right, b.right);
    final intersectionBottom = min(a.bottom, b.bottom);

    final intersectionWidth = max(0.0, intersectionRight - intersectionLeft);
    final intersectionHeight = max(0.0, intersectionBottom - intersectionTop);
    final intersectionArea = intersectionWidth * intersectionHeight;

    final unionArea = a.area + b.area - intersectionArea;

    if (unionArea <= 0) return 0.0;

    return intersectionArea / unionArea;
  }

  bool _isValidConfidence(double value) {
    if (value.isNaN || value.isInfinite) return false;

    return value >= 0.0 && value <= 1.0;
  }

  bool _isValidClassId(int classId) {
    return classId >= 0 && classId < _labels.length;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0.0;
  }

  double _clamp01(double value) {
    return value.clamp(0.0, 1.0).toDouble();
  }

  void _sendOk(dynamic id, Map<String, dynamic> data) {
    _mainSendPort.send({'id': id, 'ok': true, ...data});
  }

  void _sendError(dynamic id, String error) {
    _mainSendPort.send({'id': id, 'ok': false, 'error': error});
  }

  void _dispose() {
    _ready = false;
    _labels = [];
    _outputShapes = [];

    try {
      _interpreter?.close();
    } catch (_) {}

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

class _WorkerDetection {
  final int classId;
  final double confidence;
  final _Box box;

  const _WorkerDetection({
    required this.classId,
    required this.confidence,
    required this.box,
  });

  Map<String, dynamic> toJson() {
    return {
      'classId': classId,
      'confidence': confidence,
      'left': box.left,
      'top': box.top,
      'right': box.right,
      'bottom': box.bottom,
    };
  }
}

class _Box {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const _Box({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => max(0.0, right - left);
  double get height => max(0.0, bottom - top);
  double get area => width * height;
}

class _NmsScoreClass {
  final double score;
  final int classId;

  const _NmsScoreClass({required this.score, required this.classId});
}
