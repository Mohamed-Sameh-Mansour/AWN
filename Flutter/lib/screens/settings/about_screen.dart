import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:myeye/screens/settings/widgets/settings_background.dart';
import 'package:myeye/screens/settings/widgets/settings_common_widgets.dart';
import 'package:myeye/screens/settings/widgets/settings_header.dart';

class AboutScreen extends StatelessWidget {
  final bool isEnglish;

  const AboutScreen({super.key, this.isEnglish = false});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
                  children: [
                    SettingsHeader(
                      isEnglish: isEnglish,
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 26),
                    SettingsGlassCard(
                      padding: const EdgeInsets.all(22),
                      borderColor: const Color(0xFF00E5FF),
                      glowColor: const Color(0xFF00E5FF),
                      child: isEnglish
                          ? const _AboutEnglishContent()
                          : const _AboutArabicContent(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutEnglishContent extends StatelessWidget {
  const _AboutEnglishContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            "Awn-عون",
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: Color(0xFF9CFDFF),
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(height: 16),
        Text(
          "An assistive app for blind and visually impaired users. It helps users understand their surroundings using the camera, AI, and Arabic voice guidance.",
          textScaler: TextScaler.noScaling,
          style: TextStyle(color: Colors.white, fontSize: 16, height: 1.55),
        ),
        SizedBox(height: 26),
        _AboutTitle("Current features"),
        SizedBox(height: 12),
        _AboutLine("Obstacle detection around the user."),
        _AboutLine("English text reading through the camera."),
        _AboutLine("Currency recognition."),
        _AboutLine("Medicine recognition assistance."),
        SizedBox(height: 26),
        _AboutTitle("How to use"),
        SizedBox(height: 12),
        Text(
          "Swipe left and right to move between features, and double tap to start the selected feature.",
          textScaler: TextScaler.noScaling,
          style: TextStyle(color: Colors.white70, fontSize: 15.5, height: 1.55),
        ),
      ],
    );
  }
}

class _AboutArabicContent extends StatelessWidget {
  const _AboutArabicContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            "Awn-عون",
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: Color(0xFF9CFDFF),
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(height: 16),
        Text(
          "تطبيق مساعد لفاقدي وضعاف البصر، يهدف إلى تسهيل التعامل مع البيئة المحيطة من خلال الكاميرا والذكاء الاصطناعي والتوجيه الصوتي.",
          textScaler: TextScaler.noScaling,
          style: TextStyle(color: Colors.white, fontSize: 16, height: 1.65),
        ),
        SizedBox(height: 26),
        _AboutTitle("الخدمات الحالية"),
        SizedBox(height: 12),
        _AboutLine("كشف العوائق أمام المستخدم."),
        _AboutLine("قراءة النصوص الإنجليزية من خلال الكاميرا."),
        _AboutLine("تحديد فئات العملات."),
        _AboutLine("المساعدة في التعرف على الدواء."),
        SizedBox(height: 26),
        _AboutTitle("طريقة الاستخدام"),
        SizedBox(height: 12),
        Text(
          "يعتمد التطبيق على السحب يمينًا ويسارًا للتنقل بين الخدمات، والضغط مرتين لتشغيل الخدمة المختارة.",
          textScaler: TextScaler.noScaling,
          style: TextStyle(color: Colors.white70, fontSize: 15.5, height: 1.65),
        ),
      ],
    );
  }
}

class _AboutTitle extends StatelessWidget {
  final String text;

  const _AboutTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textScaler: TextScaler.noScaling,
      style: const TextStyle(
        color: Color(0xFF9CFDFF),
        fontSize: 21,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _AboutLine extends StatelessWidget {
  final String text;

  const _AboutLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "•  ",
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
