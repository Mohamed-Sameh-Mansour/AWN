import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myeye/core/tts/tts_voice_prefs.dart';
import 'package:myeye/screens/settings/about_screen.dart';
import 'package:myeye/screens/settings/models/settings_ui_language.dart';
import 'package:myeye/screens/settings/widgets/settings_about_card.dart';
import 'package:myeye/screens/settings/widgets/settings_background.dart';
import 'package:myeye/screens/settings/widgets/settings_header.dart';
import 'package:myeye/screens/settings/widgets/settings_language_card.dart';
import 'package:myeye/screens/settings/widgets/settings_voice_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _uiLanguageKey = 'myeye_ui_language';
  static const String _settingsIntroSpeech =
      'الإعدادات. يمكنك تغيير اللغة والصوت من هنا.';

  final FlutterTts _tts = FlutterTts();

  bool _loadingVoices = true;
  bool _uiLanguageChanged = false;
  bool _isClosing = false;
  bool _introSpoken = false;

  SettingsUiLanguage _uiLanguage = SettingsUiLanguage.ar;
  List<Map<String, String>> _arabicVoices = [];
  Map<String, String>? _selectedVoice;

  bool get _isEnglish => _uiLanguage == SettingsUiLanguage.en;

  @override
  void initState() {
    super.initState();
    _loadUiLanguage();
    _initTtsAndVoices();
  }

  Future<void> _loadUiLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_uiLanguageKey) ?? 'ar';

    if (!mounted) return;

    setState(() {
      _uiLanguage = saved == 'en'
          ? SettingsUiLanguage.en
          : SettingsUiLanguage.ar;
    });
  }

  Future<void> _setUiLanguage(SettingsUiLanguage language) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _uiLanguageKey,
      language == SettingsUiLanguage.en ? 'en' : 'ar',
    );

    if (!mounted) return;

    setState(() {
      _uiLanguage = language;
      _uiLanguageChanged = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          language == SettingsUiLanguage.en
              ? 'Interface language changed to English'
              : 'تم تغيير لغة الواجهة إلى العربية',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _initTtsAndVoices() async {
    await _tts.setLanguage("ar-EG");
    await _tts.setSpeechRate(0.50);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(false);

    final raw = await _tts.getVoices;
    final voices = <Map<String, String>>[];

    for (final v in raw) {
      if (v is Map) {
        final name = (v["name"] ?? "").toString();
        final locale = (v["locale"] ?? "").toString();

        final nameLower = name.toLowerCase();
        final localeLower = locale.toLowerCase();

        final isArabicVoice =
            localeLower.startsWith("ar") || nameLower.startsWith("ar");

        final isLocalVoice =
            nameLower.contains("local") && !nameLower.contains("network");

        if (isArabicVoice && isLocalVoice) {
          voices.add({"name": name, "locale": locale});
        }
      }
    }

    final saved = await TtsVoicePrefs.loadVoice();
    Map<String, String>? selected;

    if (saved != null && voices.isNotEmpty) {
      for (final voice in voices) {
        if (voice["name"] == saved["name"] &&
            voice["locale"] == saved["locale"]) {
          selected = voice;
          break;
        }
      }
    }

    if (selected != null) {
      await _setTtsVoiceOnly(selected);
    } else if (saved != null) {
      await TtsVoicePrefs.clearVoice();
    }

    if (!mounted) return;

    setState(() {
      _arabicVoices = voices;
      _selectedVoice = selected;
      _loadingVoices = false;
    });

    await _speakSettingsIntro();
  }

  Future<void> _speakSettingsIntro() async {
    if (_introSpoken) return;
    if (_isClosing) return;
    if (!mounted) return;

    _introSpoken = true;

    try {
      await _tts.stop();
      await TtsVoicePrefs.applySavedVoice(_tts);
      await _tts.speak(_settingsIntroSpeech);
    } catch (_) {}
  }

  Future<void> _setTtsVoiceOnly(Map<String, String> voice) async {
    final name = voice["name"] ?? "";
    final locale = voice["locale"] ?? "";

    if (name.isEmpty || locale.isEmpty) return;

    try {
      await _tts.setLanguage(locale);
      await _tts.setVoice({"name": name, "locale": locale});
    } catch (_) {}
  }

  Future<void> _applyVoice(
    Map<String, String> voice, {
    bool speakTest = true,
  }) async {
    final name = voice["name"] ?? "";
    final locale = voice["locale"] ?? "";

    if (name.isEmpty || locale.isEmpty) return;

    try {
      await _tts.setLanguage(locale);
      await _tts.setVoice({"name": name, "locale": locale});

      await TtsVoicePrefs.saveVoice(name: name, locale: locale);

      if (speakTest) {
        await _tts.stop();
        await _tts.speak("هذا صوت تجريبي من عَوْن");
      }
    } catch (_) {}
  }

  Future<void> _resetVoiceToDefault() async {
    try {
      await TtsVoicePrefs.clearVoice();

      await _tts.stop();
      await _tts.setLanguage("ar-EG");
      await _tts.setSpeechRate(0.50);
      await _tts.setPitch(1.0);

      if (!mounted) return;

      setState(() {
        _selectedVoice = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEnglish
                ? 'App voice has been reset to the device default'
                : 'تمت استعادة صوت الجهاز الافتراضي',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _tts.speak(
        _isEnglish
            ? 'The app voice has been reset to the device default.'
            : 'تمت استعادة صوت الجهاز الافتراضي.',
      );
    } catch (_) {}
  }

  void _closeSettings() {
    if (_isClosing) return;
    _isClosing = true;

    Navigator.of(context).pop(_uiLanguageChanged);
  }

  @override
  void dispose() {
    try {
      _tts.stop();
    } catch (_) {}

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = _isEnglish;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _closeSettings();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Color(0xFF020712),
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Directionality(
          textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFF020712),
            body: Stack(
              children: [
                const Positioned.fill(child: SettingsBackground()),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 390;

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          narrow ? 18 : 22,
                          narrow ? 16 : 22,
                          narrow ? 18 : 22,
                          24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SettingsHeader(
                              isEnglish: isEnglish,
                              onBack: _closeSettings,
                            ),
                            SizedBox(height: narrow ? 22 : 28),
                            SettingsLanguageCard(
                              isEnglish: isEnglish,
                              selectedLanguage: _uiLanguage,
                              onLanguageChanged: _setUiLanguage,
                            ),
                            SizedBox(height: narrow ? 18 : 22),
                            SettingsVoiceCard(
                              isEnglish: isEnglish,
                              loading: _loadingVoices,
                              voices: _arabicVoices,
                              selectedVoice: _selectedVoice,
                              onVoiceChanged: (voice) async {
                                if (voice == null) return;

                                setState(() {
                                  _selectedVoice = voice;
                                });

                                await _applyVoice(voice, speakTest: true);
                              },
                              onResetVoice: _resetVoiceToDefault,
                            ),
                            SizedBox(height: narrow ? 18 : 22),
                            SettingsAboutCard(
                              isEnglish: isEnglish,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AboutScreen(isEnglish: isEnglish),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
