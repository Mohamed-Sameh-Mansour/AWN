import 'package:permission_handler/permission_handler.dart';

typedef PermissionSpeechCallback = Future<void> Function(String message);

class PermissionService {
  const PermissionService._();

  static Future<bool> ensureCameraPermission({
    PermissionSpeechCallback? speak,
  }) async {
    return _ensurePermission(
      permission: Permission.camera,
      speak: speak,
      beforeRequestMessage: ' إذن الكاميرا. اضغط سماح .',
      grantedMessage: 'تم السماح بإذن الكاميرا.',
      deniedMessage:
          'لم يتم السماح بإذن الكاميرا. التطبيق يحتاج إذن الكاميرا للتشغيل.',
      permanentlyDeniedMessage:
          'إذن الكاميرا مرفوض نهائيًا. افتح إعدادات التطبيق وفعّل إذن الكاميرا.',
    );
  }

  static Future<bool> ensureMicrophonePermission({
    PermissionSpeechCallback? speak,
  }) async {
    return _ensurePermission(
      permission: Permission.microphone,
      speak: speak,
      beforeRequestMessage: ' إذن الميكروفون. اضغط سماح .',
      grantedMessage: 'تم السماح بإذن الميكروفون.',
      deniedMessage:
          'لم يتم السماح بإذن الميكروفون. الأوامر الصوتية تحتاج إذن الميكروفون.',
      permanentlyDeniedMessage:
          'إذن الميكروفون مرفوض نهائيًا. افتح إعدادات التطبيق وفعّل إذن الميكروفون.',
    );
  }

  static Future<bool> _ensurePermission({
    required Permission permission,
    required String beforeRequestMessage,
    required String grantedMessage,
    required String deniedMessage,
    required String permanentlyDeniedMessage,
    PermissionSpeechCallback? speak,
  }) async {
    final currentStatus = await permission.status;

    if (currentStatus.isGranted || currentStatus.isLimited) {
      return true;
    }

    if (currentStatus.isPermanentlyDenied || currentStatus.isRestricted) {
      await _safeSpeak(speak, permanentlyDeniedMessage);
      return false;
    }

    await _safeSpeak(speak, beforeRequestMessage);

    // مهم جدًا: ندي فرصة للصوت يخلص قبل ما Dialog النظام يظهر.
    await Future.delayed(const Duration(milliseconds: 900));

    final requestedStatus = await permission.request();

    if (requestedStatus.isGranted || requestedStatus.isLimited) {
      await _safeSpeak(speak, grantedMessage);
      return true;
    }

    if (requestedStatus.isPermanentlyDenied || requestedStatus.isRestricted) {
      await _safeSpeak(speak, permanentlyDeniedMessage);
      return false;
    }

    await _safeSpeak(speak, deniedMessage);
    return false;
  }

  static Future<void> _safeSpeak(
    PermissionSpeechCallback? speak,
    String message,
  ) async {
    if (speak == null) return;

    try {
      await speak(message);
    } catch (_) {
      // منخليش مشكلة الصوت توقف طلب الإذن.
    }
  }
}
