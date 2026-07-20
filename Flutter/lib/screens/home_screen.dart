import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_brand.dart';
import '../core/constants/app_constants.dart';
import '../core/features/app_feature.dart';
import '../features/currency/currency_camera_screen.dart';
import '../features/medicine/screens/medicine_camera_screen.dart';
import '../features/object_identifier/screens/object_identifier_camera_screen.dart';
import '../features/obstacle/screens/obstacle_camera_screen.dart';
import '../features/text_reader/screens/text_reader_camera_screen.dart';
import 'home/models/home_feature_meta.dart';
import 'home/services/home_tts_service.dart';
import 'home/widgets/home_background.dart';
import 'home/widgets/home_bottom_guide_banner.dart';
import 'home/widgets/home_feature_card.dart';
import 'home/widgets/home_header.dart';
import 'home/widgets/home_intro_title.dart';
import 'settings_screen.dart';

enum _UiLanguage { ar, en }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _uiLanguageKey = AppBrand.uiLanguagePreferenceKey;
  static const Duration _afterFeatureBackDelay = Duration(milliseconds: 550);

  final HomeTtsService _homeTts = HomeTtsService();

  AppFeature? current;
  double _dragDx = 0;
  _UiLanguage _uiLanguage = _UiLanguage.ar;

  final List<AppFeature> features = const [
    AppFeature.obstacle,
    AppFeature.objectDetector,
    AppFeature.textReader,
    AppFeature.currency,
    AppFeature.medicine,
  ];

  bool get _isEnglish => _uiLanguage == _UiLanguage.en;

  @override
  void initState() {
    super.initState();
    _loadUiLanguage();
    _boot();
  }

  Future<void> _loadUiLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_uiLanguageKey) ?? 'ar';

    if (!mounted) return;

    setState(() {
      _uiLanguage = saved == 'en' ? _UiLanguage.en : _UiLanguage.ar;
    });
  }

  Future<void> _openSettings() async {
    await _stopSpeak();

    if (!mounted) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );

    await _homeTts.refreshVoice();

    if (changed == true) {
      await _loadUiLanguage();
    }

    if (!mounted) return;

    await _announceBackHome();
  }

  Future<void> _boot() async {
    await _homeTts.ready;
    await _speak(AppBrand.welcomeSpeech);
  }

  Future<void> _stopSpeak() async {
    await _homeTts.stop();
  }

  Future<void> _speak(
    String text, {
    Duration delayBeforeSpeak = Duration.zero,
  }) async {
    await _homeTts.speak(
      text,
      delayBeforeSpeak: delayBeforeSpeak,
      canSpeak: () => mounted,
    );
  }

  int _indexOf(AppFeature f) => features.indexOf(f);

  AppFeature _nextFeature(AppFeature f) {
    final i = _indexOf(f);
    if (i < 0) return features.first;
    if (i >= features.length - 1) return f;
    return features[i + 1];
  }

  AppFeature _prevFeature(AppFeature f) {
    final i = _indexOf(f);
    if (i <= 0) return f;
    return features[i - 1];
  }

  String _featureName(AppFeature f) => f.title;

  String _hintFor(AppFeature f) => f.hint;

  String _movementGuideText(AppFeature f) {
    final i = _indexOf(f);

    final canGoNext = i < features.length - 1;
    final canGoPrev = i > 0;

    final nextName = canGoNext ? _featureName(features[i + 1]) : null;
    final prevName = canGoPrev ? _featureName(features[i - 1]) : null;

    final buffer = StringBuffer();

    if (canGoNext && nextName != null) {
      buffer.write('للوصول إلى $nextName اسحب يمين. ');
    } else {
      buffer.write('لا يوجد خدمات بعد ذلك. ');
    }

    if (canGoPrev && prevName != null) {
      buffer.write('للرجوع إلى $prevName اسحب شمال.');
    }

    return buffer.toString().trim();
  }

  String _guideText(AppFeature f) {
    final buffer = StringBuffer();

    buffer.write('${_featureName(f)}. ');
    buffer.write('${_hintFor(f)} ');
    buffer.write(_movementGuideText(f));

    return buffer.toString().trim();
  }

  String _backHomeGuideText(AppFeature f) {
    final buffer = StringBuffer();

    buffer.write('أنت في الشاشة الرئيسية. ');
    buffer.write('أنت الآن على ${_featureName(f)}. ');
    buffer.write('${_hintFor(f)} ');
    buffer.write(_movementGuideText(f));

    return buffer.toString().trim();
  }

  Future<void> _announceCurrent() async {
    if (current == null) return;
    await _speak(_guideText(current!));
  }

  Future<void> _announceBackHome() async {
    if (!mounted) return;

    final String message;

    if (current == null) {
      message = 'أنت في الشاشة الرئيسية. اسحب يمين للتنقل بين الخدمات.';
    } else {
      message = _backHomeGuideText(current!);
    }

    await _speak(message, delayBeforeSpeak: _afterFeatureBackDelay);
  }

  Future<void> onSwipeRight() async {
    if (current == null) {
      setState(() => current = features.first);
      unawaited(_announceCurrent());
      return;
    }

    if (current == features.last) {
      unawaited(_announceCurrent());
      return;
    }

    final next = _nextFeature(current!);
    setState(() => current = next);
    unawaited(_announceCurrent());
  }

  Future<void> onSwipeLeft() async {
    if (current == null) {
      unawaited(_speak('اسحب يمين للتنقل بين الخدمات.'));
      return;
    }

    if (current == features.first) {
      unawaited(_announceCurrent());
      return;
    }

    final prev = _prevFeature(current!);
    setState(() => current = prev);
    unawaited(_announceCurrent());
  }

  Future<void> onDoubleTap() async {
    await _stopSpeak();

    if (current == null) {
      await _speak('اسحب يمين للتنقل بين الخدمات.');
      return;
    }

    if (current == AppFeature.obstacle) {
      await _speak('فتح كاميرا كاشف العوائق.');
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const ObstacleCameraScreen()),
      );

      await _announceBackHome();
      return;
    }

    if (current == AppFeature.objectDetector) {
      await _speak('فتح كاميرا كاشف الأشياء.');
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ObjectIdentifierCameraScreen(),
        ),
      );

      await _announceBackHome();
      return;
    }

    if (current == AppFeature.textReader) {
      await _speak('فتح قارئ النصوص.');
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const TextReaderCameraScreen()),
      );

      await _announceBackHome();
      return;
    }

    if (current == AppFeature.currency) {
      await _speak('فتح قارئ العملات.');
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const CurrencyCameraScreen()),
      );

      await _announceBackHome();
      return;
    }

    if (current == AppFeature.medicine) {
      await _speak('فتح قارئ الأدوية.');
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const MedicineCameraScreen()),
      );

      await _announceBackHome();
      return;
    }

    await _speak('تم تشغيل ${_featureName(current!)}.');
  }

  @override
  void dispose() {
    _homeTts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = _isEnglish;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF020712),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (details) => _dragDx = 0,
        onHorizontalDragUpdate: (details) => _dragDx += details.delta.dx,
        onHorizontalDragEnd: (details) async {
          if (_dragDx > HomeConstants.swipeThreshold) {
            await onSwipeRight();
          } else if (_dragDx < -HomeConstants.swipeThreshold) {
            await onSwipeLeft();
          }

          _dragDx = 0;
        },
        onDoubleTap: onDoubleTap,
        child: Scaffold(
          backgroundColor: const Color(0xFF020712),
          body: Stack(
            children: [
              const Positioned.fill(child: HomeBackground()),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact =
                        constraints.maxHeight < 760 ||
                        constraints.maxWidth < 390;

                    final horizontalPadding = compact ? 18.0 : 22.0;
                    final topGap = compact ? 12.0 : 16.0;
                    final headerGap = compact ? 10.0 : 14.0;
                    final cardGap = compact ? 10.0 : 12.0;
                    final cardHeight = compact ? 102.0 : 108.0;

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            topGap,
                            horizontalPadding,
                            18,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              HomeHeader(onSettingsPressed: _openSettings),
                              SizedBox(height: headerGap),
                              HomeIntroTitle(isEnglish: isEnglish),
                              SizedBox(height: compact ? 16 : 20),
                              for (int i = 0; i < features.length; i++) ...[
                                HomeFeatureCard(
                                  meta: HomeFeatureMetaRepository.metaOf(
                                    features[i],
                                  ),
                                  selected: current == features[i],
                                  height: cardHeight,
                                  isEnglish: isEnglish,
                                  onTap: () async {
                                    setState(() => current = features[i]);
                                    unawaited(_announceCurrent());
                                  },
                                ),
                                if (i != features.length - 1)
                                  SizedBox(height: cardGap),
                              ],
                              SizedBox(height: compact ? 14 : 18),
                              HomeBottomGuideBanner(isEnglish: isEnglish),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
