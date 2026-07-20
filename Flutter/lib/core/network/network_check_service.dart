import 'dart:async';
import 'dart:io';

class NetworkCheckService {
  static const String noInternetMessage =
      'مفيش إنترنت حاليا. شغّل النت وجرب تاني.';

  static const String serverProblemMessage =
      'الإنترنت شغال، لكن السيرفر مش بيرد حاليا. جرّب تاني بعد لحظات.';

  static const String serverTimeoutMessage =
      'السيرفر أخد وقت طويل ومردش. جرّب تاني بعد لحظات.';

  static const String serverWakeUpMessage =
      'السيرفر غالبا بيفتح دلوقتي. انتظر لحظات وجرب تاني.';

  static const String serverBusyMessage =
      'السيرفر مشغول حاليا. جرّب تاني بعد شوية.';

  static const String invalidServerResponseMessage =
      'السيرفر رد برد غير مفهوم. جرّب تاني بعد لحظات.';

  static const String emptyServerResponseMessage =
      'السيرفر مردش بنتيجة واضحة. جرّب تاني.';

  static const String wrongApiLinkMessage =
      'لينك السيرفر غير صحيح أو الخدمة غير موجودة.';

  static const String unauthorizedMessage =
      'في مشكلة في صلاحية الوصول للسيرفر أو مفتاح الـ API.';

  static const String imageTooLargeMessage =
      'الصورة كبيرة على السيرفر. جرّب تقرّب وتصور صورة أوضح وأخف.';

  static const String tooManyRequestsMessage =
      'في طلبات كتير على السيرفر حاليا. جرّب تاني بعد لحظات.';

  static Future<bool> hasInternetConnection({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(timeout);

      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      try {
        final result = await InternetAddress.lookup(
          'cloudflare.com',
        ).timeout(timeout);

        return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  static Future<void> ensureInternetConnection() async {
    final hasInternet = await hasInternetConnection();

    if (!hasInternet) {
      throw const NetworkUnavailableException();
    }
  }

  static String messageForHttpStatus(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return unauthorizedMessage;
    }

    if (statusCode == 404) {
      return wrongApiLinkMessage;
    }

    if (statusCode == 408 || statusCode == 504) {
      return serverTimeoutMessage;
    }

    if (statusCode == 413) {
      return imageTooLargeMessage;
    }

    if (statusCode == 429) {
      return tooManyRequestsMessage;
    }

    if (statusCode == 503) {
      return serverWakeUpMessage;
    }

    if (statusCode >= 500 && statusCode <= 599) {
      return serverProblemMessage;
    }

    if (statusCode >= 400 && statusCode <= 499) {
      return invalidServerResponseMessage;
    }

    return serverProblemMessage;
  }
}

class NetworkUnavailableException implements Exception {
  final String message;

  const NetworkUnavailableException([
    this.message = NetworkCheckService.noInternetMessage,
  ]);

  @override
  String toString() {
    return message;
  }
}
