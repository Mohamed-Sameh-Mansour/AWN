import 'package:myeye/core/camera/auto_flash_service.dart';

class ObjectIdentifierAutoFlashService extends AutoFlashService {
  ObjectIdentifierAutoFlashService()
    : super(
        sampleCount: 900,
        turnOnLuminance: 48.0,
        turnOffLuminance: 78.0,
        darkFramesToTurnOn: 2,
        brightFramesToTurnOff: 4,
        minCheckInterval: const Duration(milliseconds: 450),

        // في معرفة الأشياء نخلي الفلاش يشتغل تلقائيًا في الضلمة
        // ويقفل لو الإضاءة بقت كافية عشان الصورة متتحرقش.
        autoTurnOffWhenBright: true,
      );
}
