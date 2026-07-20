import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/config/app_api_config.dart';
import '../../../core/network/network_check_service.dart';
import '../models/medicine_detection_result.dart';

class MedicineApiService {
  final String endpointUrl;
  final String imageFieldName;
  final String apiKey;
  final String keyFieldName;
  final Duration timeout;
  final bool usesNgrok;

  MedicineApiService({
    this.endpointUrl = AppApiConfig.medicineEndpointUrl,
    this.imageFieldName = AppApiConfig.medicineImageFieldName,
    this.apiKey = AppApiConfig.medicineApiKey,
    this.keyFieldName = AppApiConfig.medicineKeyFieldName,
    this.timeout = AppApiConfig.medicineTimeout,
    this.usesNgrok = AppApiConfig.medicineUsesNgrok,
  });

  Uri get _url => Uri.parse(endpointUrl);

  Future<List<MedicineDetectionResult>> detectDrugFromImageFile(
    String imagePath,
  ) async {
    final file = File(imagePath);

    if (!await file.exists()) {
      throw MedicineApiException('ملف الصورة غير موجود', details: imagePath);
    }

    await _ensureInternet();

    final mediaType = await _detectImageMediaType(file);

    if (mediaType == null) {
      throw const MedicineApiException(
        'صيغة الصورة غير مدعومة. لازم JPEG أو PNG',
      );
    }

    try {
      final request = http.MultipartRequest('POST', _url);

      request.headers.addAll(
        usesNgrok
            ? AppApiConfig.ngrokJsonHeaders
            : AppApiConfig.defaultJsonHeaders,
      );

      final cleanApiKey = apiKey.trim();

      if (cleanApiKey.isNotEmpty) {
        request.fields[keyFieldName] = cleanApiKey;
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          imageFieldName,
          imagePath,
          filename: mediaType.subtype == 'png'
              ? 'medicine_image.png'
              : 'medicine_image.jpg',
          contentType: mediaType,
        ),
      );

      final streamedResponse = await request.send().timeout(timeout);

      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(timeout);

      final body = utf8.decode(response.bodyBytes).trim();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MedicineApiException(
          NetworkCheckService.messageForHttpStatus(response.statusCode),
          details: 'HTTP ${response.statusCode}: $body',
          isNoInternet: false,
        );
      }

      if (body.isEmpty) {
        throw const MedicineApiException(
          NetworkCheckService.emptyServerResponseMessage,
          details: 'Empty response from medicine API',
          isNoInternet: false,
        );
      }

      final decoded = _decodeJson(body);

      _throwIfApiReturnedError(decoded, rawBody: body);

      final results = MedicineDetectionResult.listFromApiJson(decoded);

      return results;
    } on MedicineApiException {
      rethrow;
    } on TimeoutException catch (e) {
      throw MedicineApiException(
        NetworkCheckService.serverTimeoutMessage,
        details: e.toString(),
        isNoInternet: false,
      );
    } on SocketException catch (e) {
      throw MedicineApiException(
        NetworkCheckService.noInternetMessage,
        details: e.toString(),
        isNoInternet: true,
      );
    } on http.ClientException catch (e) {
      final hasInternet = await NetworkCheckService.hasInternetConnection();

      throw MedicineApiException(
        hasInternet
            ? NetworkCheckService.serverProblemMessage
            : NetworkCheckService.noInternetMessage,
        details: e.toString(),
        isNoInternet: !hasInternet,
      );
    } catch (e) {
      throw MedicineApiException(
        NetworkCheckService.serverProblemMessage,
        details: e.toString(),
        isNoInternet: false,
      );
    }
  }

  dynamic _decodeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      throw MedicineApiException(
        NetworkCheckService.invalidServerResponseMessage,
        details: 'Invalid JSON: $body',
        isNoInternet: false,
      );
    }
  }

  void _throwIfApiReturnedError(dynamic decoded, {required String rawBody}) {
    if (decoded is! Map<String, dynamic>) return;

    final success = decoded['success'];

    if (success == false) {
      final apiMessage = _extractApiMessage(decoded);

      throw MedicineApiException(
        apiMessage.isEmpty
            ? NetworkCheckService.invalidServerResponseMessage
            : apiMessage,
        details: rawBody,
        isNoInternet: false,
      );
    }

    final hasExplicitError =
        decoded.containsKey('error') ||
        decoded.containsKey('detail') ||
        decoded.containsKey('details');

    final hasUsefulData =
        decoded.containsKey('data') ||
        decoded.containsKey('result') ||
        decoded.containsKey('results') ||
        decoded.containsKey('prediction') ||
        decoded.containsKey('predictions') ||
        decoded.containsKey('drug_name') ||
        decoded.containsKey('drug_name_ar') ||
        decoded.containsKey('medicine_name') ||
        decoded.containsKey('name');

    if (hasExplicitError && !hasUsefulData) {
      final apiMessage = _extractApiMessage(decoded);

      throw MedicineApiException(
        apiMessage.isEmpty
            ? NetworkCheckService.invalidServerResponseMessage
            : apiMessage,
        details: rawBody,
        isNoInternet: false,
      );
    }
  }

  Future<void> _ensureInternet() async {
    try {
      await NetworkCheckService.ensureInternetConnection();
    } on NetworkUnavailableException catch (e) {
      throw MedicineApiException(e.message, isNoInternet: true);
    }
  }

  Future<MediaType?> _detectImageMediaType(File file) async {
    final bytes = await file.openRead(0, 12).fold<List<int>>(<int>[], (
      previous,
      element,
    ) {
      previous.addAll(element);
      return previous;
    });

    if (bytes.length < 4) return null;

    final isJpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;

    if (isJpeg) {
      return MediaType('image', 'jpeg');
    }

    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;

    if (isPng) {
      return MediaType('image', 'png');
    }

    return null;
  }

  String _extractApiMessage(Map<String, dynamic> json) {
    final possibleKeys = const [
      'message',
      'error',
      'detail',
      'details',
      'reason',
    ];

    for (final key in possibleKeys) {
      final value = json[key];

      if (value == null) continue;

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }

      if (value is List && value.isNotEmpty) {
        return value.toString();
      }

      if (value is Map && value.isNotEmpty) {
        return value.toString();
      }
    }

    return '';
  }
}

class MedicineApiException implements Exception {
  final String message;
  final String? details;
  final bool isNoInternet;

  const MedicineApiException(
    this.message, {
    this.details,
    this.isNoInternet = false,
  });

  @override
  String toString() {
    if (details == null || details!.trim().isEmpty) {
      return message;
    }

    return '$message: $details';
  }
}
