import 'package:myeye/core/camera/auto_flash_service.dart';

class CurrencyAutoFlashService extends AutoFlashService {
  CurrencyAutoFlashService()
    : super(
        sampleCount: 900,
        turnOnLuminance: 48.0,
        turnOffLuminance: 78.0,
        darkFramesToTurnOn: 2,
        brightFramesToTurnOff: 4,
        minCheckInterval: const Duration(milliseconds: 450),

        // في العملات نخلي الفلاش يفضل شغال أثناء القراءة
        // ويتقفل عند انتهاء المحاولة أو الخروج من الشاشة.
        autoTurnOffWhenBright: false,
      );
}
