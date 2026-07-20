import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';

import 'package:myeye/core/camera/input_frame.dart';
import 'package:myeye/features/obstacle/models/obstacle_detection_result.dart';
import 'package:myeye/features/obstacle/models/obstacle_label.dart';
import 'package:myeye/features/obstacle/services/obstacle_inference_worker.dart';

class ObstacleInferenceService {
  static const String modelAssetPath = 'assets/models/best_int8.tflite';

  static const String labelsAssetPath =
      'assets/labels/obstacle_yolov11_labels.txt';

  static const int numClasses = 12;

  final double confidenceThreshold;
  final double iouThreshold;

  ObstacleInferenceService({
    this.confidenceThreshold = 0.30,
    this.iouThreshold = 0.45,
  });

  bool _isReady = false;
  bool _disposed = false;

  Isolate? _workerIsolate;
  ReceivePort? _receivePort;
  StreamSubscription<dynamic>? _receiveSubscription;
  SendPort? _workerSendPort;

  Completer<SendPort>? _workerReadyCompleter;

  final Map<int, Completer<Map<dynamic, dynamic>>> _pendingRequests = {};

  int _nextRequestId = 0;

  List<String> _labels = [];

  bool get isReady => _isReady;

  List<String> get labels => List.unmodifiable(_labels);

  Future<void> init() async {
    _disposed = false;

    final labelsString = await rootBundle.loadString(labelsAssetPath);

    _labels = labelsString
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map(_cleanLabelLine)
        .toList();

    if (_labels.length != numClasses) {
      throw StateError(
        'Obstacle labels count must be $numClasses, found ${_labels.length}',
      );
    }

    final modelData = await rootBundle.load(modelAssetPath);

    final modelBytes = Uint8List.fromList(
      modelData.buffer.asUint8List(
        modelData.offsetInBytes,
        modelData.lengthInBytes,
      ),
    );

    final receivePort = ReceivePort();

    _receivePort = receivePort;
    _workerReadyCompleter = Completer<SendPort>();

    _receiveSubscription = receivePort.listen(_handleWorkerMessage);

    _workerIsolate = await Isolate.spawn(
      obstacleInferenceWorkerMain,
      receivePort.sendPort,
      debugName: 'ObstacleInferenceWorker',
    );

    _workerSendPort = await _workerReadyCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Obstacle worker did not start.');
      },
    );

    await _sendRequest({
      'type': 'init',
      'modelBytes': TransferableTypedData.fromList([modelBytes]),
      'labels': _labels,
      'numClasses': numClasses,
      'confidenceThreshold': confidenceThreshold,
      'iouThreshold': iouThreshold,
    }, timeout: const Duration(seconds: 30));

    _isReady = true;
  }

  Future<List<ObstacleDetectionResult>> detectFromFrame(
    InputFrame frame,
  ) async {
    if (!_isReady || _disposed) return [];

    final planes = frame.image.planes.map((plane) {
      return {
        'bytes': TransferableTypedData.fromList([
          Uint8List.fromList(plane.bytes),
        ]),
        'bytesPerRow': plane.bytesPerRow,
        'bytesPerPixel': plane.bytesPerPixel ?? 1,
      };
    }).toList();

    final response = await _sendRequest({
      'type': 'detect',
      'width': frame.image.width,
      'height': frame.image.height,
      'rotationDegrees': frame.rotationDegrees,
      'planes': planes,
    }, timeout: const Duration(seconds: 5));

    final rawDetections = response['detections'];

    if (rawDetections is! List) return [];

    final detections = <ObstacleDetectionResult>[];

    for (final item in rawDetections) {
      if (item is! Map) continue;

      final classId = _toInt(item['classId']);
      final confidence = _toDouble(item['confidence']);

      if (confidence < confidenceThreshold) continue;
      if (!_isValidClassId(classId)) continue;

      final left = _toDouble(item['left']);
      final top = _toDouble(item['top']);
      final right = _toDouble(item['right']);
      final bottom = _toDouble(item['bottom']);

      if (right <= left || bottom <= top) continue;

      final rawLabel = _labels[classId];
      final label = ObstacleClassProfiles.fromModelLabel(rawLabel);

      detections.add(
        ObstacleDetectionResult(
          classId: classId,
          rawLabel: rawLabel,
          label: label,
          confidence: confidence,
          box: Rect.fromLTRB(left, top, right, bottom),
        ),
      );
    }

    return detections;
  }

  Future<Map<dynamic, dynamic>> _sendRequest(
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_disposed) {
      throw StateError('Obstacle inference service disposed.');
    }

    final sendPort = _workerSendPort;

    if (sendPort == null) {
      throw StateError('Obstacle worker is not ready.');
    }

    final id = ++_nextRequestId;
    final completer = Completer<Map<dynamic, dynamic>>();

    _pendingRequests[id] = completer;

    sendPort.send({...payload, 'id': id});

    try {
      final response = await completer.future.timeout(timeout);

      if (response['ok'] != true) {
        throw StateError(
          response['error']?.toString() ?? 'Obstacle worker error.',
        );
      }

      return response;
    } finally {
      _pendingRequests.remove(id);
    }
  }

  void _handleWorkerMessage(dynamic message) {
    if (_disposed) return;

    if (message is SendPort) {
      if (_workerReadyCompleter != null &&
          !_workerReadyCompleter!.isCompleted) {
        _workerReadyCompleter!.complete(message);
      }

      return;
    }

    if (message is! Map) return;

    final id = message['id'];

    if (id is! int) return;

    final completer = _pendingRequests[id];

    if (completer == null || completer.isCompleted) return;

    completer.complete(Map<dynamic, dynamic>.from(message));
  }

  bool _isValidClassId(int classId) {
    return classId >= 0 && classId < _labels.length;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();

    return int.tryParse(value.toString()) ?? -1;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0.0;
  }

  String _cleanLabelLine(String line) {
    return line.replaceFirst(RegExp(r'^\s*\d+\s*[:\-.]\s*'), '').trim();
  }

  void dispose() {
    _disposed = true;
    _isReady = false;

    try {
      _workerSendPort?.send({'type': 'dispose', 'id': ++_nextRequestId});
    } catch (_) {}

    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Obstacle inference disposed.'));
      }
    }

    _pendingRequests.clear();

    _receiveSubscription?.cancel();
    _receiveSubscription = null;

    _receivePort?.close();
    _receivePort = null;

    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;

    _workerSendPort = null;
    _workerReadyCompleter = null;

    _labels = [];
  }
}
