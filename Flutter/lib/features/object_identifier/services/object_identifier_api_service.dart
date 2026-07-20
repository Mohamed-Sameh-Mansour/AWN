import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/config/app_api_config.dart';
import '../../../core/network/network_check_service.dart';
import '../models/object_identifier_result.dart';

class ObjectIdentifierApiService {
  final String apiUrl;
  final String fileFieldName;
  final Duration timeout;

  ObjectIdentifierApiService({
    this.apiUrl = AppApiConfig.objectIdentifierApiUrl,
    this.fileFieldName = AppApiConfig.objectIdentifierFileFieldName,
    this.timeout = AppApiConfig.objectIdentifierTimeout,
  });

  Future<ObjectIdentifierResult?> analyzeImageFile(String imagePath) async {
    final file = File(imagePath);

    if (!await file.exists()) {
      throw ObjectIdentifierApiException(
        'ملف الصورة غير موجود',
        details: imagePath,
      );
    }

    await _ensureInternet();

    try {
      final request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      request.headers.addAll(AppApiConfig.defaultJsonHeaders);

      request.files.add(
        await http.MultipartFile.fromPath(
          fileFieldName,
          imagePath,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send().timeout(timeout);

      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(timeout);

      final body = utf8.decode(response.bodyBytes).trim();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ObjectIdentifierApiException(
          NetworkCheckService.messageForHttpStatus(response.statusCode),
          details: 'HTTP ${response.statusCode}: $body',
          isNoInternet: false,
        );
      }

      if (body.isEmpty) {
        throw const ObjectIdentifierApiException(
          NetworkCheckService.emptyServerResponseMessage,
          details: 'Empty response from object identifier API',
          isNoInternet: false,
        );
      }

      dynamic decoded;

      try {
        decoded = jsonDecode(body);
      } catch (_) {
        throw ObjectIdentifierApiException(
          NetworkCheckService.invalidServerResponseMessage,
          details: 'Invalid JSON: $body',
          isNoInternet: false,
        );
      }

      if (decoded is Map<String, dynamic>) {
        final success = decoded['success'];

        if (success == false) {
          final message = _extractErrorMessage(decoded);

          throw ObjectIdentifierApiException(
            message.trim().isEmpty
                ? NetworkCheckService.invalidServerResponseMessage
                : message,
            details: body,
            isNoInternet: false,
          );
        }
      }

      final result = ObjectIdentifierResult.fromApiJson(decoded);

      if (!result.hasUsefulText) {
        return null;
      }

      return result;
    } on ObjectIdentifierApiException {
      rethrow;
    } on TimeoutException catch (e) {
      throw ObjectIdentifierApiException(
        NetworkCheckService.serverTimeoutMessage,
        details: e.toString(),
        isNoInternet: false,
      );
    } on SocketException catch (e) {
      throw ObjectIdentifierApiException(
        NetworkCheckService.noInternetMessage,
        details: e.toString(),
        isNoInternet: true,
      );
    } on http.ClientException catch (e) {
      final hasInternet = await NetworkCheckService.hasInternetConnection();

      throw ObjectIdentifierApiException(
        hasInternet
            ? NetworkCheckService.serverProblemMessage
            : NetworkCheckService.noInternetMessage,
        details: e.toString(),
        isNoInternet: !hasInternet,
      );
    } catch (e) {
      throw ObjectIdentifierApiException(
        NetworkCheckService.serverProblemMessage,
        details: e.toString(),
        isNoInternet: false,
      );
    }
  }

  Future<void> _ensureInternet() async {
    try {
      await NetworkCheckService.ensureInternetConnection();
    } on NetworkUnavailableException catch (e) {
      throw ObjectIdentifierApiException(e.message, isNoInternet: true);
    }
  }

  String _extractErrorMessage(Map<String, dynamic> json) {
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

    return NetworkCheckService.invalidServerResponseMessage;
  }
}

class ObjectIdentifierApiException implements Exception {
  final String message;
  final String? details;
  final bool isNoInternet;

  const ObjectIdentifierApiException(
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
