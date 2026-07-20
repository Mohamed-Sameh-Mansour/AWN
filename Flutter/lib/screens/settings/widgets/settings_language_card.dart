import 'package:flutter/material.dart';

import 'package:myeye/screens/settings/models/settings_ui_language.dart';
import 'package:myeye/screens/settings/widgets/settings_common_widgets.dart';

class SettingsLanguageCard extends StatelessWidget {
  final bool isEnglish;
  final SettingsUiLanguage selectedLanguage;
  final ValueChanged<SettingsUiLanguage> onLanguageChanged;

  const SettingsLanguageCard({
    super.key,
    required this.isEnglish,
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 390;

    return SettingsGlassCard(
      padding: EdgeInsets.all(narrow ? 18 : 22),
      borderColor: const Color(0xFF00E5FF),
      glowColor: const Color(0xFF00E5FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(
            icon: Icons.language_rounded,
            iconColor: const Color(0xFF22F3FF),
            title: isEnglish ? 'Interface language' : 'لغة الواجهة',
            subtitle: isEnglish ? 'English' : 'العربية',
          ),
          SizedBox(height: narrow ? 18 : 22),
          Row(
            children: [
              Expanded(
                child: _LanguageOptionTile(
                  title: 'العربية',
                  subtitle: 'Arabic UI',
                  selected: selectedLanguage == SettingsUiLanguage.ar,
                  accent: const Color(0xFF00E5FF),
                  onTap: () => onLanguageChanged(SettingsUiLanguage.ar),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LanguageOptionTile(
                  title: 'English',
                  subtitle: 'English UI',
                  selected: selectedLanguage == SettingsUiLanguage.en,
                  accent: const Color(0xFFB978FF),
                  onTap: () => onLanguageChanged(SettingsUiLanguage.en),
                ),
              ),
            ],
          ),
          SizedBox(height: narrow ? 18 : 22),
          Text(
            isEnglish
                ? 'This changes only the visible interface text.\nVoice guidance stays Arabic.'
                : 'ده بيغيّر الكلام الظاهر في التصميم فقط.\nالتوجيه الصوتي يفضل عربي زي ما هو.',
            textAlign: isEnglish ? TextAlign.left : TextAlign.right,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: narrow ? 15 : 16.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _LanguageOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 390;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: narrow ? 140 : 152,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: selected
                ? RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.1,
                    colors: [
                      accent.withValues(alpha: 0.27),
                      const Color(0xFF061221).withValues(alpha: 0.96),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF061221).withValues(alpha: 0.92),
                      const Color(0xFF020814).withValues(alpha: 0.96),
                    ],
                  ),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.95)
                  : const Color(0xFF00E5FF).withValues(alpha: 0.28),
              width: selected ? 1.8 : 1.1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.25),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? accent : Colors.white.withValues(alpha: 0.55),
                size: narrow ? 32 : 36,
              ),
              SizedBox(height: narrow ? 14 : 18),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: narrow ? 19 : 21,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.66),
                  fontSize: narrow ? 14.5 : 16,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
