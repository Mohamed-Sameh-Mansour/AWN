import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/camera/camera_session.dart';
import '../../../core/camera/input_frame.dart';
import '../../../core/voice/feature_voice_command_service.dart';
import '../controllers/text_reader_controller.dart';
import '../models/text_reader_ui_state.dart';

class TextReaderCameraScreen extends StatefulWidget {
  const TextReaderCameraScreen({super.key});

  @override
  State<TextReaderCameraScreen> createState() => _TextReaderCameraScreenState();
}

class _TextReaderCameraScreenState extends State<TextReaderCameraScreen> {
  final TextReaderController _controller = TextReaderController();

  final FeatureVoiceCommandService _voiceCommands = FeatureVoiceCommandService(
    debugName: 'text_reader',
  );

  static const Color _bg = Color(0xFF020611);
  static const Color _cardBg = Color(0xEE0D0B23);
  static const Color _purple = Color(0xFF8B5CFF);
  static const Color _purpleLight = Color(0xFFB08CFF);
  static const Color _green = Color(0xFF1ED760);

  static const List<FeatureVoiceCommand> _captureAndExitCommands = [
    FeatureVoiceCommand(id: FeatureVoiceCommandIds.start, phrases: ['تصوير']),
    FeatureVoiceCommand(
      id: FeatureVoiceCommandIds.exit,
      phrases: ['اغلاق', 'إغلاق'],
    ),
  ];

  static const List<FeatureVoiceCommand> _exitOnlyCommands = [
    FeatureVoiceCommand(
      id: FeatureVoiceCommandIds.exit,
      phrases: ['اغلاق', 'إغلاق'],
    ),
  ];

  bool _closing = false;
  bool _voiceStarted = false;
  bool _readingRunning = false;

  @override
  void initState() {
    super.initState();

    unawaited(_initFeature());
  }

  Future<void> _initFeature() async {
    await _controller.init();

    if (!mounted || _closing) return;

    if (!_controller.uiState.isCameraAllowed) return;

    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted || _closing) return;

    await _startVoiceCommands();
  }

  Future<void> _startVoiceCommands() async {
    if (_voiceStarted || _closing) return;

    _voiceStarted = true;

    final started = await _voiceCommands.start(
      commands: _captureAndExitCommands,
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 12),
      onCommand: (commandId, _) async {
        if (!mounted || _closing) return;

        if (commandId == FeatureVoiceCommandIds.start) {
          if (_readingRunning || _controller.uiState.isBusy) return;

          unawaited(_runReadCommand());
          return;
        }

        if (commandId == FeatureVoiceCommandIds.exit) {
          await _exitToHome();
        }
      },
    );

    if (!started) {
      _voiceStarted = false;
    }
  }

  Future<void> _runReadCommand({bool forceRestart = false}) async {
    if (_closing) return;

    /*
      لو هو بيقرأ حاليًا وعملت Double Tap:
      نوقف القراءة فورًا ونبدأ قراءة جديدة.
    */
    if (_readingRunning || _controller.uiState.isBusy) {
      if (!forceRestart) return;

      await _controller.cancelCurrentOperation();

      if (!mounted || _closing) return;

      _readingRunning = false;

      await Future.delayed(const Duration(milliseconds: 160));
    }

    _readingRunning = true;

    /*
      وقت التحليل والقراءة:
      نخلي المايك يسمع إغلاق فقط عشان ميبدأش تصوير جديد بالغلط.
    */
    _voiceCommands.replaceCommands(_exitOnlyCommands);

    await _voiceCommands.resume(after: const Duration(milliseconds: 180));

    await _controller.readText();

    if (!mounted || _closing) {
      _readingRunning = false;
      return;
    }

    /*
      بعد ما القراءة والتعليمات يخلصوا:
      نرجّع تصوير / إغلاق فقط.
    */
    _voiceCommands.replaceCommands(_captureAndExitCommands);

    _readingRunning = false;

    await _voiceCommands.resume(after: const Duration(milliseconds: 300));
  }

  Future<void> _handleDoubleTap() async {
    await _runReadCommand(forceRestart: true);
  }

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity > 250) {
      unawaited(_runReadCommand(forceRestart: true));
    }
  }

  void _rescan() {
    unawaited(_runReadCommand(forceRestart: true));
  }

  Future<void> _exitToHome() async {
    if (_closing) return;

    _closing = true;

    await _voiceCommands.stop();
    await _controller.disposeController();

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    unawaited(_voiceCommands.dispose());
    unawaited(_controller.disposeController());
    _controller.dispose();
    super.dispose();
  }

  String _modeShortText(TextReaderUiState state) {
    if (state.mode == TextReaderMode.arabic) {
      return 'سيرفر';
    }

    return 'أوفلاين';
  }

  String _mainStatusTitle(TextReaderUiState state) {
    if (state.isBusy) return 'جاري المسح';

    if (state.recognizedText.trim().isNotEmpty) {
      return 'تمت القراءة';
    }

    return 'جاهز';
  }

  String _mainStatusSubtitle(TextReaderUiState state) {
    if (state.isBusy) return 'ثبّت الكاميرا';

    if (state.recognizedText.trim().isNotEmpty) {
      return _modeShortText(state);
    }

    return 'قل تصوير أو إغلاق';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: _handleDoubleTap,
            onHorizontalDragEnd: _handleSwipe,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final state = _controller.uiState;

                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.15,
                      colors: [
                        Color(0xFF101A32),
                        Color(0xFF050915),
                        Color(0xFF01030A),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      _topBar(context),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  10,
                                  14,
                                  128,
                                ),
                                child: state.isCameraAllowed
                                    ? _cameraPreview(state)
                                    : _permissionMessage(
                                        state.titleText,
                                        state.subtitleText,
                                      ),
                              ),
                            ),
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 18,
                              child: _bottomStatusPanel(state),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: IconButton(
                onPressed: () => unawaited(_exitToHome()),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          ),
          const Text(
            'قراءة النصوص',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cameraPreview(TextReaderUiState state) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.18),
            blurRadius: 26,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraSession(
              resolutionPreset: ResolutionPreset.high,
              minFrameInterval: const Duration(seconds: 1),
              onSessionReady: _controller.attachSession,
              onFrame: (InputFrame frame) async {
                await _controller.onFrame(frame);
              },
              builder: (context, preview) => preview,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.04),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.24),
                  ],
                ),
              ),
            ),
            Positioned(top: 16, left: 16, child: _flashBadge(state.isTorchOn)),
            if (state.isBusy)
              Container(
                color: Colors.black.withValues(alpha: 0.25),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: _purpleLight,
                    strokeWidth: 3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _flashBadge(bool isTorchOn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTorchOn ? Icons.flash_on_rounded : Icons.flash_auto_rounded,
            color: Colors.white,
            size: 19,
          ),
          const SizedBox(width: 7),
          Text(
            isTorchOn ? 'الفلاش شغال' : 'فلاش تلقائي',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomStatusPanel(TextReaderUiState state) {
    final hasText = state.recognizedText.trim().isNotEmpty;
    final title = _mainStatusTitle(state);
    final subtitle = _mainStatusSubtitle(state);

    return Container(
      height: hasText ? 238 : 178,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _purple.withValues(alpha: 0.58), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.20),
            blurRadius: 28,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _rescanButton(),
              const SizedBox(width: 18),
              Expanded(
                child: _statusTexts(
                  state: state,
                  title: title,
                  subtitle: subtitle,
                ),
              ),
            ],
          ),
          if (hasText) ...[
            const SizedBox(height: 14),
            Expanded(child: _recognizedTextBox(state.recognizedText)),
          ],
        ],
      ),
    );
  }

  Widget _rescanButton() {
    return SizedBox(
      width: 150,
      height: 58,
      child: OutlinedButton.icon(
        onPressed: _rescan,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(
            color: _purpleLight.withValues(alpha: 0.85),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.03),
        ),
        icon: const Icon(Icons.camera_alt_rounded, size: 24),
        label: const Text(
          'تصوير',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _statusTexts({
    required TextReaderUiState state,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'الحالة',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.touch_app_rounded, color: _purpleLight, size: 23),
          ],
        ),
      ],
    );
  }

  Widget _recognizedTextBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Text(
          text,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.55,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _permissionMessage(String title, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: _purple.withValues(alpha: 0.45)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Text(
            '$title\n\n$subtitle',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              height: 1.6,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
