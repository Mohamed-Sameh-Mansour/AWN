import 'package:myeye/core/camera/auto_flash_service.dart';

class ObstacleAutoFlashService extends AutoFlashService {
  ObstacleAutoFlashService()
    : super(
        sampleCount: 900,

        // لو الصورة ضلمة، شغل الفلاش بسرعة.
        turnOnLuminance: 52.0,

        // مايقفلش الفلاش إلا لو الصورة منورة بوضوح.
        // الرقم العالي هنا مقصود عشان الفلاش نفسه ما يخدعش الكاميرا.
        turnOffLuminance: 135.0,

        // أي بيكسل أقل من الرقم ده بنعتبره ضلمة.
        darkPixelLuminance: 58.0,

        // لو لسه فيه أكتر من 12% من الصورة ضلمة، الفلاش يفضل شغال.
        turnOffMaxDarkPixelRatio: 0.12,

        // شغل بعد فريمين ضلمة.
        darkFramesToTurnOn: 2,

        // اقفل بعد 10 قراءات متتالية الصورة فيها منورة فعلًا.
        brightFramesToTurnOff: 10,

        minCheckInterval: const Duration(milliseconds: 450),

        // بعد ما الفلاش يشتغل، سيبه شغال شوية وما تقفلوش فورًا.
        // ده بيمنع مشكلة إنه يفتح ويقفل كل شوية.
        minTorchOnDuration: const Duration(seconds: 6),

        // في كاشف العوائق نقفله بس لو الإضاءة رجعت كويسة فعلًا.
        autoTurnOffWhenBright: true,
      );
}
