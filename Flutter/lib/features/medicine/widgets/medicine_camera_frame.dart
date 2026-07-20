import 'package:flutter/material.dart';

class MedicineCameraFrame extends StatelessWidget {
  final Widget preview;
  final bool isBusy;
  final bool isTorchOn;
  final VoidCallback onCapture;
  final VoidCallback onDoubleTapCapture;

  const MedicineCameraFrame({
    super.key,
    required this.preview,
    required this.isBusy,
    required this.isTorchOn,
    required this.onCapture,
    required this.onDoubleTapCapture,
  });

  static const Color _accent = Color(0xFFFF8A2B);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: onDoubleTapCapture,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          border: Border.all(
            color: _accent.withValues(alpha: 0.92),
            width: 1.35,
          ),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.20),
              blurRadius: 34,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF111827), Color(0xFF050914)],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: Stack(
            children: [
              Positioned.fill(child: preview),

              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.02),
                        Colors.black.withValues(alpha: 0.04),
                        Colors.black.withValues(alpha: 0.30),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 18,
                left: 18,
                child: _AutoFlashBadge(isActive: isTorchOn),
              ),

              const Positioned(
                top: 18,
                right: 18,
                child: _CornerBracket(alignment: _CornerAlignment.topRight),
              ),

              const Positioned(
                bottom: 18,
                right: 18,
                child: _CornerBracket(alignment: _CornerAlignment.bottomRight),
              ),

              const Positioned(
                bottom: 18,
                left: 18,
                child: _CornerBracket(alignment: _CornerAlignment.bottomLeft),
              ),

              if (isBusy)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.66),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _accent.withValues(alpha: 0.50),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'جاري التحليل...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: _CaptureButton(enabled: !isBusy, onTap: onCapture),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoFlashBadge extends StatelessWidget {
  final bool isActive;

  const _AutoFlashBadge({required this.isActive});

  static const Color _accent = Color(0xFFFF8A2B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.flash_on_rounded : Icons.bolt_rounded,
            size: 20,
            color: isActive ? _accent : Colors.white,
          ),
          const SizedBox(width: 9),
          const Text(
            'تلقائي',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _CaptureButton({required this.enabled, required this.onTap});

  static const Color _accent = Color(0xFFFF8A2B);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'التقاط صورة الدواء',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.55,
          duration: const Duration(milliseconds: 180),
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.70),
              border: Border.all(color: _accent, width: 2.6),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.55),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.24),
                  blurRadius: 26,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.16),
                    Colors.black.withValues(alpha: 0.70),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _CornerAlignment { topRight, bottomRight, bottomLeft }

class _CornerBracket extends StatelessWidget {
  final _CornerAlignment alignment;

  const _CornerBracket({required this.alignment});

  static const Color _accent = Color(0xFFFF8A2B);

  bool get _isTop => alignment == _CornerAlignment.topRight;

  bool get _isRight =>
      alignment == _CornerAlignment.topRight ||
      alignment == _CornerAlignment.bottomRight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        children: [
          Align(
            alignment: _alignment,
            child: Container(
              width: 34,
              height: 3,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Align(
            alignment: _alignment,
            child: Container(
              width: 3,
              height: 34,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Alignment get _alignment {
    if (_isTop && _isRight) return Alignment.topRight;
    if (!_isTop && _isRight) return Alignment.bottomRight;
    return Alignment.bottomLeft;
  }
}
