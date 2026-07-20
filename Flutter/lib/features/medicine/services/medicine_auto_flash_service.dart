import 'package:myeye/core/camera/auto_flash_service.dart';

class MedicineAutoFlashService extends AutoFlashService {
  MedicineAutoFlashService()
    : super(
        sampleCount: 900,

        // لو صورة الدواء ضلمة، شغل الفلاش بسرعة.
        turnOnLuminance: 48.0,

        // في الدواء مش عايزين الفلاش يفضل مولع كتير.
        // أول ما الإضاءة تبقى كفاية، يطفي بعد شوية بسيطة.
        turnOffLuminance: 82.0,

        // أي بيكسل أقل من الرقم ده بنعتبره جزء ضلمة.
        darkPixelLuminance: 55.0,

        // لو نسبة الضلمة قليلة، يبقى الإضاءة كفاية ونقدر نطفي الفلاش.
        turnOffMaxDarkPixelRatio: 0.24,

        // شغل بعد فريمين ضلمة متتاليين.
        darkFramesToTurnOn: 2,

        // اقفل بعد 4 قراءات منورة متتالية.
        // ده أسرع من القديم، بس لسه بيمنع الرعشة.
        brightFramesToTurnOff: 4,

        minCheckInterval: const Duration(milliseconds: 450),

        // سيب الفلاش شغال لحظة صغيرة عشان الصورة تثبت،
        // بس مش مدة طويلة تخليه يحرق الصورة أو يفضل منور.
        minTorchOnDuration: const Duration(seconds: 2),

        // الدواء لازم يبقى ذكي:
        // ينور في الضلمة ويطفي لو الإضاءة بقت كافية.
        autoTurnOffWhenBright: true,
      );
}
