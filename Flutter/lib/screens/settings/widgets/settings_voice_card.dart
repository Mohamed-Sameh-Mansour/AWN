import 'package:flutter/material.dart';

import 'package:myeye/screens/settings/widgets/settings_common_widgets.dart';

class SettingsVoiceCard extends StatelessWidget {
  final bool isEnglish;
  final bool loading;
  final List<Map<String, String>> voices;
  final Map<String, String>? selectedVoice;
  final ValueChanged<Map<String, String>?> onVoiceChanged;
  final VoidCallback onResetVoice;

  const SettingsVoiceCard({
    super.key,
    required this.isEnglish,
    required this.loading,
    required this.voices,
    required this.selectedVoice,
    required this.onVoiceChanged,
    required this.onResetVoice,
  });

  String _voiceLabel(Map<String, String>? voice) {
    if (voice == null) {
      return isEnglish ? 'Device default voice' : 'صوت الجهاز الافتراضي';
    }

    final index = voices.indexWhere(
      (item) =>
          item["name"] == voice["name"] && item["locale"] == voice["locale"],
    );

    if (index < 0) {
      return isEnglish ? 'Selected voice' : 'الصوت المختار';
    }

    return isEnglish ? 'Voice ${index + 1}' : 'صوت ${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final voiceText = _voiceLabel(selectedVoice);
    final narrow = MediaQuery.sizeOf(context).width < 390;

    return SettingsGlassCard(
      padding: EdgeInsets.all(narrow ? 18 : 22),
      borderColor: const Color(0xFF8C4DFF),
      glowColor: const Color(0xFF8C4DFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(
            icon: Icons.record_voice_over_rounded,
            iconColor: const Color(0xFFB978FF),
            title: isEnglish ? 'App voice' : 'صوت التطبيق',
            subtitle: loading
                ? (isEnglish ? 'Loading…' : 'جاري التحميل…')
                : voiceText,
          ),
          SizedBox(height: narrow ? 20 : 24),
          if (loading)
            const _LoadingVoiceBox()
          else if (voices.isEmpty)
            _EmptyVoiceBox(isEnglish: isEnglish)
          else ...[
            _VoiceDropdown(
              isEnglish: isEnglish,
              voices: voices,
              selectedVoice: selectedVoice,
              onChanged: onVoiceChanged,
            ),
            SizedBox(height: narrow ? 12 : 14),
            _ResetVoiceButton(isEnglish: isEnglish, onPressed: onResetVoice),
          ],
        ],
      ),
    );
  }
}

class _LoadingVoiceBox extends StatelessWidget {
  const _LoadingVoiceBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
        ),
      ),
      child: const CircularProgressIndicator(
        strokeWidth: 2.4,
        color: Color(0xFF00E5FF),
      ),
    );
  }
}

class _EmptyVoiceBox extends StatelessWidget {
  final bool isEnglish;

  const _EmptyVoiceBox({required this.isEnglish});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.55)),
        color: Colors.orangeAccent.withValues(alpha: 0.08),
      ),
      child: Text(
        isEnglish
            ? 'No local Arabic voices are available on this device. Enable or download Arabic Text-to-Speech voices from phone settings.'
            : 'لا توجد أصوات عربية محلية على هذا الجهاز. فعّل أو حمّل أصوات عربية من إعدادات تحويل النص إلى كلام.',
        textAlign: isEnglish ? TextAlign.left : TextAlign.right,
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14.5,
          height: 1.4,
        ),
      ),
    );
  }
}

class _VoiceDropdown extends StatelessWidget {
  final bool isEnglish;
  final List<Map<String, String>> voices;
  final Map<String, String>? selectedVoice;
  final ValueChanged<Map<String, String>?> onChanged;

  const _VoiceDropdown({
    required this.isEnglish,
    required this.voices,
    required this.selectedVoice,
    required this.onChanged,
  });

  String _voiceLabel(int index) {
    return isEnglish ? 'Voice ${index + 1}' : 'صوت ${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final label = isEnglish ? 'Choose local voice' : 'اختار الصوت المحلي';

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.72),
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF9CFDFF),
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: const Color(0xFF020814).withValues(alpha: 0.72),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.55),
            width: 1.1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.9),
            width: 1.5,
          ),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, String>>(
          value: selectedVoice,
          isExpanded: true,
          dropdownColor: const Color(0xFF071322),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF9CFDFF),
            size: 30,
          ),
          hint: Text(
            isEnglish
                ? 'Use device default voice'
                : 'استخدام صوت الجهاز الافتراضي',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
          ),
          items: List.generate(voices.length, (index) {
            final voice = voices[index];

            return DropdownMenuItem<Map<String, String>>(
              value: voice,
              child: Text(
                _voiceLabel(index),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ResetVoiceButton extends StatelessWidget {
  final bool isEnglish;
  final VoidCallback onPressed;

  const _ResetVoiceButton({required this.isEnglish, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.settings_voice_rounded, size: 20),
      label: Text(
        isEnglish
            ? 'Reset to device default voice'
            : 'استعادة صوت الجهاز الافتراضي',
        textScaler: TextScaler.noScaling,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF9CFDFF),
        side: BorderSide(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.55),
          width: 1.1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}
