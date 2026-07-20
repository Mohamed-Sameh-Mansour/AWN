import 'package:flutter/material.dart';

class MedicineResultCard extends StatelessWidget {
  final String statusText;
  final String titleText;
  final String subtitleText;
  final String actionText;
  final bool isBusy;
  final bool isActionEnabled;
  final VoidCallback onListen;

  const MedicineResultCard({
    super.key,
    required this.statusText,
    required this.titleText,
    required this.subtitleText,
    required this.actionText,
    required this.isBusy,
    required this.isActionEnabled,
    required this.onListen,
  });

  static const Color _accent = Color(0xFFFF8A2B);
  static const Color _softTitle = Color(0xFFFFE1B7);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxHeight < 190;

        final double padding = compact ? 13 : 15;
        final double iconSize = compact ? 62 : 72;
        final double iconRadius = compact ? 18 : 21;
        final double titleSize = compact ? 22 : 25;
        final double subtitleSize = compact ? 13 : 14;
        final double buttonHeight = compact ? 48 : 54;

        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _accent.withValues(alpha: 0.48),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.12),
                blurRadius: 26,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.50),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF081322), Color(0xFF030812)],
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: compact ? 24 : 26,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        statusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          color: isBusy ? _accent : Colors.white60,
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isBusy ? Colors.white70 : _accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.45),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'الحالة',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: compact ? 15 : 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: compact ? 8 : 10),

              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _MedicineIconBox(size: iconSize, radius: iconRadius),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            titleText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: _softTitle,
                              fontSize: titleSize,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitleText,
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: subtitleSize,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: compact ? 8 : 10),

              GestureDetector(
                onTap: isActionEnabled ? onListen : null,
                child: AnimatedOpacity(
                  opacity: isActionEnabled ? 1 : 0.50,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    height: buttonHeight,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          _accent.withValues(alpha: 0.34),
                          const Color(0xFF080B12).withValues(alpha: 0.78),
                          _accent.withValues(alpha: 0.18),
                        ],
                      ),
                      border: Border.all(
                        color: _accent.withValues(alpha: 0.56),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.12),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.graphic_eq_rounded,
                          color: _accent,
                          size: 23,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            actionText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 16 : 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MedicineIconBox extends StatelessWidget {
  final double size;
  final double radius;

  const _MedicineIconBox({required this.size, required this.radius});

  static const Color _accent = Color(0xFFFF8A2B);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF9638), Color(0xFFC76316), Color(0xFF8D3C0B)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.28),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.medical_services_outlined, color: Colors.white, size: 32),
          Positioned(
            right: 15,
            bottom: 14,
            child: Icon(Icons.add_box_outlined, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }
}
