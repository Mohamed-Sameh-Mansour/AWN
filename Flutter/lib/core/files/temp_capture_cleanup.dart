import 'dart:io';

class TempCaptureCleanup {
  const TempCaptureCleanup._();

  static Future<void> deleteCapturedImage(String? imagePath) async {
    if (imagePath == null) return;

    final cleanPath = imagePath.trim();
    if (cleanPath.isEmpty) return;

    try {
      final file = File(cleanPath);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      /*
        التنضيف تحسين فقط.
        لو الصورة مش موجودة أو النظام رفض يمسحها،
        ماينفعش ده يأثر على نتيجة التحليل أو تشغيل التطبيق.
      */
    }
  }
}
