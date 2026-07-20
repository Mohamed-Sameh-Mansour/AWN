import 'package:flutter/material.dart';

class CurrencyBottomHint extends StatelessWidget {
  const CurrencyBottomHint({
    super.key,
    required this.text,
    required this.primaryGreen,
    required this.mutedText,
  });

  final String text;
  final Color primaryGreen;
  final Color mutedText;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.touch_app_outlined, color: primaryGreen, size: 28),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: mutedText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
