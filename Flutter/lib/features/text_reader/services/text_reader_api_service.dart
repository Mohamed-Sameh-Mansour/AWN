import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/config/app_api_config.dart';
import '../../../core/network/network_check_service.dart';
import '../models/text_reader_result.dart';

class TextReaderApiService {
  final String endpointUrl;
  final String imageFieldName;
  final Duration timeout;
  final bool usesNgrok;

  TextReaderApiService({
    this.endpointUrl = AppApiConfig.arabicOcrEndpointUrl,
    this.imageFieldName = AppApiConfig.arabicOcrImageFieldName,
    this.timeout = AppApiConfig.arabicOcrTimeout,
    this.usesNgrok = AppApiConfig.arabicOcrUsesNgrok,
  });

  Future<TextReaderResult> extractArabicFromImageFile(String imagePath) async {
    final file = File(imagePath);

    if (!await file.exists()) {
      throw const TextReaderApiException('ملف الصورة غير موجود');
    }

    await _ensureInternet();

    final mediaType = await _detectImageMediaType(file);

    if (mediaType == null) {
      throw const TextReaderApiException(
        'صيغة الصورة غير مدعومة. لازم JPEG أو PNG',
      );
    }

    try {
      final request = http.MultipartRequest('POST', Uri.parse(endpointUrl));

      request.headers.addAll(
        usesNgrok
            ? AppApiConfig.ngrokJsonHeaders
            : AppApiConfig.defaultJsonHeaders,
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          imageFieldName,
          imagePath,
          filename: mediaType.subtype == 'png'
              ? 'text_image.png'
              : 'text_image.jpg',
          contentType: mediaType,
        ),
      );

      final streamedResponse = await request.send().timeout(timeout);

      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(timeout);

      final body = utf8.decode(response.bodyBytes).trim();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TextReaderApiException(
          NetworkCheckService.messageForHttpStatus(response.statusCode),
          details: 'HTTP ${response.statusCode}: $body',
          isNoInternet: false,
        );
      }

      if (body.isEmpty) {
        throw const TextReaderApiException(
          NetworkCheckService.emptyServerResponseMessage,
          details: 'Empty response from Arabic OCR API',
          isNoInternet: false,
        );
      }

      dynamic decoded;

      try {
        decoded = jsonDecode(body);
      } catch (_) {
        throw TextReaderApiException(
          NetworkCheckService.invalidServerResponseMessage,
          details: 'Invalid JSON: $body',
          isNoInternet: false,
        );
      }

      if (decoded is! Map<String, dynamic>) {
        throw TextReaderApiException(
          NetworkCheckService.invalidServerResponseMessage,
          details: 'Unexpected response shape: $body',
          isNoInternet: false,
        );
      }

      final result = TextReaderResult.fromJson(decoded);

      if (!result.hasText) {
        throw TextReaderApiException(
          'مش قادر أقرأ النص بوضوح. قرّب الكاميرا وثبّت الإضاءة وجرب تاني.',
          details: body,
          isNoInternet: false,
        );
      }

      return result;
    } on TextReaderApiException {
      rethrow;
    } on TimeoutException catch (e) {
      throw TextReaderApiException(
        NetworkCheckService.serverTimeoutMessage,
        details: e.toString(),
        isNoInternet: false,
      );
    } on SocketException catch (e) {
      throw TextReaderApiException(
        NetworkCheckService.noInternetMessage,
        details: e.toString(),
        isNoInternet: true,
      );
    } on http.ClientException catch (e) {
      final hasInternet = await NetworkCheckService.hasInternetConnection();

      throw TextReaderApiException(
        hasInternet
            ? NetworkCheckService.serverProblemMessage
            : NetworkCheckService.noInternetMessage,
        details: e.toString(),
        isNoInternet: !hasInternet,
      );
    } catch (e) {
      throw TextReaderApiException(
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
      throw TextReaderApiException(e.message, isNoInternet: true);
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
}

class TextReaderApiException implements Exception {
  final String message;
  final String? details;
  final bool isNoInternet;

  const TextReaderApiException(
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
