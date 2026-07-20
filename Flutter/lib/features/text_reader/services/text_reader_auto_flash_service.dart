import 'package:myeye/core/camera/auto_flash_service.dart';

class TextReaderAutoFlashService extends AutoFlashService {
  TextReaderAutoFlashService()
    : super(
        sampleCount: 900,
        turnOnLuminance: 48.0,
        turnOffLuminance: 78.0,
        darkFramesToTurnOn: 2,
        brightFramesToTurnOff: 4,
        minCheckInterval: const Duration(milliseconds: 450),

        // قارئ النصوص ممكن يقفل الفلاش تلقائيًا لو الإضاءة بقت كفاية
        // عشان النص ميتحرقش من النور.
        autoTurnOffWhenBright: true,
      );
}
