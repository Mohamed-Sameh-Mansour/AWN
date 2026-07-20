import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';

import 'package:myeye/core/camera/input_frame.dart';
import 'package:myeye/features/currency/models/currency_detection_result.dart';
import 'package:myeye/features/currency/services/currency_inference_worker.dart';

class CurrencyInferenceService {
  static const String modelAssetPath = 'assets/models/best_float16.tflite';
  static const String labelsAssetPath = 'assets/labels/Label.txt';

  static const double confidenceThreshold = 0.50;
  static const double iouThreshold = 0.45;

  bool _isReady = false;
  bool _disposed = false;

  int _inputSize = 640;

  List<String> _labels = [];

  Isolate? _workerIsolate;
  ReceivePort? _receivePort;
  StreamSubscription<dynamic>? _receiveSubscription;
  SendPort? _workerSendPort;

  Completer<SendPort>? _workerReadyCompleter;

  final Map<int, Completer<Map<dynamic, dynamic>>> _pendingRequests = {};

  int _nextRequestId = 0;

  bool get isReady => _isReady;
  int get inputSize => _inputSize;

  Future<void> init() async {
    _disposed = false;

    final labelsStr = await rootBundle.loadString(labelsAssetPath);

    _labels = labelsStr
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map(_cleanLabelLine)
        .toList();

    if (_labels.isEmpty) {
      throw StateError('Currency labels file is empty.');
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
      currencyInferenceWorkerMain,
      receivePort.sendPort,
      debugName: 'CurrencyInferenceWorker',
    );

    _workerSendPort = await _workerReadyCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Currency worker did not start.');
      },
    );

    final response = await _sendRequest({
      'type': 'init',
      'modelBytes': TransferableTypedData.fromList([modelBytes]),
      'numClasses': _labels.length,
      'confidenceThreshold': confidenceThreshold,
      'iouThreshold': iouThreshold,
    }, timeout: const Duration(seconds: 30));

    final inputSize = response['inputSize'];

    if (inputSize is int && inputSize > 0) {
      _inputSize = inputSize;
    }

    _isReady = true;
  }

  Future<CurrencyDetectionResult?> detectFromFrame(InputFrame frame) async {
    if (!_isReady || _disposed) return null;

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

    final rawDetection = response['bestDetection'];

    if (rawDetection is! Map) return null;

    final classId = _toInt(rawDetection['classId']);
    final confidence = _toDouble(rawDetection['confidence']);

    if (classId < 0 || classId >= _labels.length) return null;

    final left = _toDouble(rawDetection['left']);
    final top = _toDouble(rawDetection['top']);
    final right = _toDouble(rawDetection['right']);
    final bottom = _toDouble(rawDetection['bottom']);

    if (right <= left || bottom <= top) return null;

    final rawLabel = _labels[classId];
    final spokenLabel = _extractMoneyValue(rawLabel);

    return CurrencyDetectionResult(
      label: spokenLabel,
      confidence: confidence,
      boundingBox: Rect.fromLTRB(left, top, right, bottom),
    );
  }

  Future<Map<dynamic, dynamic>> _sendRequest(
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_disposed) {
      throw StateError('Currency inference service disposed.');
    }

    final sendPort = _workerSendPort;

    if (sendPort == null) {
      throw StateError('Currency worker is not ready.');
    }

    final id = ++_nextRequestId;
    final completer = Completer<Map<dynamic, dynamic>>();

    _pendingRequests[id] = completer;

    sendPort.send({...payload, 'id': id});

    try {
      final response = await completer.future.timeout(timeout);

      if (response['ok'] != true) {
        throw StateError(
          response['error']?.toString() ?? 'Currency worker error.',
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

  String _extractMoneyValue(String label) {
    final match = RegExp(r'\d+(\.\d+)?').firstMatch(label);

    if (match == null) {
      if (label.contains('خمسين')) return '50 جنيه';
      return label;
    }

    final value = double.tryParse(match.group(0)!);

    if (value == null) return label;

    if ((value - 0.25).abs() < 0.0001) return 'ربع جنيه';
    if ((value - 0.5).abs() < 0.0001) return 'نص جنيه';
    if ((value - 1.0).abs() < 0.0001) return 'جنيه';

    return '${value.round()} جنيه';
  }

  String _cleanLabelLine(String line) {
    return line.replaceFirst(RegExp(r'^\s*\d+\s*[\.\-:]?\s*'), '').trim();
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

  void dispose() {
    _disposed = true;
    _isReady = false;

    try {
      _workerSendPort?.send({'type': 'dispose', 'id': ++_nextRequestId});
    } catch (_) {}

    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Currency inference disposed.'));
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
    _inputSize = 640;
  }
}
