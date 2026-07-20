import 'package:flutter/material.dart';

class CurrencyResultCard extends StatelessWidget {
  const CurrencyResultCard({
    super.key,
    required this.label,
    required this.guideText,
    required this.confidenceText,
    required this.primaryGreen,
    required this.softGreen,
    required this.glass,
    required this.glassDeep,
    required this.mutedText,
    required this.compact,
  });

  final String label;
  final String guideText;
  final String confidenceText;
  final Color primaryGreen;
  final Color softGreen;
  final Color glass;
  final Color glassDeep;
  final Color mutedText;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = compact ? 18.0 : 20.0;
    final verticalTop = compact ? 16.0 : 18.0;
    final verticalBottom = compact ? 16.0 : 20.0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        verticalTop,
        horizontalPadding,
        verticalBottom,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [glass, glassDeep],
        ),
        border: Border.all(
          color: primaryGreen.withValues(alpha: 0.55),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withValues(alpha: 0.16),
            blurRadius: 28,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الحالة',
                style: TextStyle(
                  color: mutedText,
                  fontSize: compact ? 17 : 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 9),
              Container(
                width: compact ? 11 : 12,
                height: compact ? 11 : 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryGreen,
                  boxShadow: [
                    BoxShadow(
                      color: primaryGreen.withValues(alpha: 0.72),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RichText(
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              text: TextSpan(
                children: _currencyTextSpans(
                  label: label,
                  primaryGreen: primaryGreen,
                  compact: compact,
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            guideText,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: mutedText,
              fontSize: compact ? 17 : 19,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          SizedBox(height: compact ? 14 : 16),
          _ConfidencePill(
            confidenceText: confidenceText,
            primaryGreen: primaryGreen,
            softGreen: softGreen,
            compact: compact,
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _currencyTextSpans({
    required String label,
    required Color primaryGreen,
    required bool compact,
  }) {
    if (label == '—') {
      return [
        TextSpan(
          text: '—',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 48 : 56,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ];
    }

    final match = RegExp(r'\d+(\.\d+)?').firstMatch(label);

    if (match == null) {
      return [
        TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 40 : 48,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ];
    }

    final before = label.substring(0, match.start);
    final number = label.substring(match.start, match.end);
    final after = label.substring(match.end);

    return [
      if (before.isNotEmpty)
        TextSpan(
          text: before,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 36 : 44,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      TextSpan(
        text: number,
        style: TextStyle(
          color: primaryGreen,
          fontSize: compact ? 54 : 64,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      if (after.isNotEmpty)
        TextSpan(
          text: after,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 36 : 44,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
    ];
  }
}

class _ConfidencePill extends StatelessWidget {
  const _ConfidencePill({
    required this.confidenceText,
    required this.primaryGreen,
    required this.softGreen,
    required this.compact,
  });

  final String confidenceText;
  final Color primaryGreen;
  final Color softGreen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 18 : 22,
        vertical: compact ? 11 : 13,
      ),
      decoration: BoxDecoration(
        color: softGreen.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: primaryGreen, width: 1.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: primaryGreen,
            size: compact ? 22 : 25,
          ),
          const SizedBox(width: 10),
          Text(
            confidenceText,
            style: TextStyle(
              color: primaryGreen,
              fontSize: compact ? 17 : 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
