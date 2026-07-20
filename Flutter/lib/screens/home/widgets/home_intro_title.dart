import 'package:flutter/material.dart';

class HomeIntroTitle extends StatelessWidget {
  final bool isEnglish;

  const HomeIntroTitle({super.key, required this.isEnglish});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 390;

    if (isEnglish) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Welcome to ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: narrow ? 26 : 29,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                TextSpan(
                  text: 'Awn-عون',
                  style: TextStyle(
                    color: const Color(0xFF9CFDFF),
                    fontSize: narrow ? 26 : 29,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.left,
            textScaler: TextScaler.noScaling,
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'أهلا بيك في ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: narrow ? 26 : 29,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              TextSpan(
                text: 'Awn-عون',
                style: TextStyle(
                  color: const Color(0xFF9CFDFF),
                  fontSize: narrow ? 26 : 29,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.right,
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}
