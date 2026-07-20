import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'package:myeye/core/camera/input_frame.dart';
import 'package:myeye/features/obstacle/models/general_object_detection_result.dart';
import 'package:myeye/features/obstacle/services/coco_obstacle_inference_worker.dart';

class ObstacleGeneralObjectService {
  ObstacleGeneralObjectService({this.confidenceThreshold = 0.25});

  static const String modelAssetPath =
      'assets/models/efficientdet_lite0.tflite';

  static const String labelsAssetPath = 'assets/labels/coco_labelmap.txt';

  final double confidenceThreshold;

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
  bool get isLoaded => _isReady;

  List<String> get labels => List.unmodifiable(_labels);

  Future<void> load() => init();

  Future<void> init() async {
    if (_isReady) return;

    _disposed = false;

    final labelsText = await rootBundle.loadString(labelsAssetPath);

    _labels = labelsText
        .split('\n')
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList();

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
      cocoObstacleInferenceWorkerMain,
      receivePort.sendPort,
      debugName: 'CocoObstacleInferenceWorker',
    );

    _workerSendPort = await _workerReadyCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('COCO worker did not start.');
      },
    );

    await _sendRequest({
      'type': 'init',
      'modelBytes': TransferableTypedData.fromList([modelBytes]),
      'confidenceThreshold': confidenceThreshold,
    }, timeout: const Duration(seconds: 30));

    _isReady = true;
  }

  Future<List<GeneralObjectDetectionResult>> detectFromFrame(
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

    final detections = <GeneralObjectDetectionResult>[];

    for (final item in rawDetections) {
      if (item is! Map) continue;

      final classIndex = _toInt(item['classIndex']);
      final score = _toDouble(item['score']);

      if (score < confidenceThreshold) continue;

      final left = _toDouble(item['left']);
      final top = _toDouble(item['top']);
      final right = _toDouble(item['right']);
      final bottom = _toDouble(item['bottom']);

      if (right <= left || bottom <= top) continue;

      detections.add(
        GeneralObjectDetectionResult(
          classIndex: classIndex,
          label: _labelForClassIndex(classIndex),
          score: score,
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        ),
      );
    }

    detections.sort((a, b) => b.score.compareTo(a.score));

    return detections;
  }

  String debugModelInfo() {
    return 'COCO worker ready=$_isReady | labels=${_labels.length} | model=$modelAssetPath';
  }

  Future<void> close() async {
    dispose();
  }

  void dispose() {
    _disposed = true;
    _isReady = false;

    try {
      _workerSendPort?.send({'type': 'dispose', 'id': ++_nextRequestId});
    } catch (_) {}

    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('COCO service disposed.'));
      }
    }

    _pendingRequests.clear();

    _receiveSubscription?.cancel();
    _receivePort?.close();
    _workerIsolate?.kill(priority: Isolate.immediate);

    _workerSendPort = null;
    _workerIsolate = null;
    _receivePort = null;
    _receiveSubscription = null;
    _workerReadyCompleter = null;
    _labels = [];
  }

  Future<Map<dynamic, dynamic>> _sendRequest(
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_disposed) {
      throw StateError('COCO service disposed.');
    }

    final sendPort = _workerSendPort;

    if (sendPort == null) {
      throw StateError('COCO worker is not ready.');
    }

    final id = ++_nextRequestId;
    final completer = Completer<Map<dynamic, dynamic>>();

    _pendingRequests[id] = completer;

    sendPort.send({...payload, 'id': id});

    try {
      final response = await completer.future.timeout(timeout);

      if (response['ok'] != true) {
        throw StateError(response['error']?.toString() ?? 'COCO worker error.');
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

  String _labelForClassIndex(int classIndex) {
    if (classIndex >= 0 && classIndex < _labels.length) {
      return _labels[classIndex];
    }

    final shiftedIndex = classIndex - 1;

    if (shiftedIndex >= 0 && shiftedIndex < _labels.length) {
      return _labels[shiftedIndex];
    }

    return 'class_$classIndex';
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
}
