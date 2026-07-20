import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsVoicePrefs {
  static const String _kVoiceName = "tts_voice_name";
  static const String _kVoiceLocale = "tts_voice_locale";

  static Future<void> saveVoice({
    required String name,
    required String locale,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVoiceName, name);
    await prefs.setString(_kVoiceLocale, locale);
  }

  static Future<void> clearVoice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kVoiceName);
    await prefs.remove(_kVoiceLocale);
  }

  static Future<Map<String, String>?> loadVoice() async {
    final prefs = await SharedPreferences.getInstance();

    final name = prefs.getString(_kVoiceName);
    final locale = prefs.getString(_kVoiceLocale);

    if (name == null || locale == null) return null;

    return {"name": name, "locale": locale};
  }

  static Future<bool> applySavedVoice(FlutterTts tts) async {
    final saved = await loadVoice();

    if (saved == null) return false;

    final name = saved["name"];
    final locale = saved["locale"];

    if (name == null || locale == null) return false;
    if (name.trim().isEmpty || locale.trim().isEmpty) return false;

    try {
      await tts.setLanguage(locale);
      await tts.setVoice({"name": name, "locale": locale});

      return true;
    } catch (_) {
      return false;
    }
  }
}
