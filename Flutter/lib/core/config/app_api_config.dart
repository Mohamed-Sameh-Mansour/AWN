class AppApiConfig {
  const AppApiConfig._();

  // =========================
  // Common API settings
  // =========================

  static const Duration shortApiTimeout = Duration(seconds: 25);
  static const Duration longApiTimeout = Duration(seconds: 90);

  static const Map<String, String> defaultJsonHeaders = {
    'Accept': 'application/json',
  };

  static const Map<String, String> ngrokJsonHeaders = {
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  // =========================
  // Arabic OCR API
  // قارئ النصوص العربي
  // =========================

  static const String arabicOcrEndpointUrl =
      'https://eng-mohamed-ahmed-blind-assistance-api.hf.space/api/v1/extract-text';

  static const String arabicOcrImageFieldName = 'image';

  static const Duration arabicOcrTimeout = longApiTimeout;

  static const bool arabicOcrUsesNgrok = false;

  // =========================
  // Medicine API
  // قارئ الأدوية
  // =========================

  static const String medicineBaseUrl =
      'https://eng-mohamed-ahmed-blind-assistance-api.hf.space';

  static const String medicineEndpointPath = '/api/v1/detect-drug';

  static const String medicineEndpointUrl =
      '$medicineBaseUrl$medicineEndpointPath';

  static const String medicineImageFieldName = 'image';

  // السيرفر الجديد زي قارئ النصوص، مش محتاج key.
  // سايبينه موجود عشان لو السيرفر اتغير بعدين وطلب key من غير ما نكسر الكود.
  static const String medicineApiKey = '';

  static const String medicineKeyFieldName = 'key';

  // Hugging Face Spaces ساعات بتاخد وقت في أول request بسبب cold start.
  static const Duration medicineTimeout = longApiTimeout;

  static const bool medicineUsesNgrok = false;

  // =========================
  // Object Identifier API
  // معرفة الأشياء
  // =========================

  static const String objectIdentifierApiUrl =
      'https://ya7ya14-blind-assistant-api.hf.space/analyze-image/';

  static const String objectIdentifierFileFieldName = 'file';

  static const Duration objectIdentifierTimeout = longApiTimeout;
}
