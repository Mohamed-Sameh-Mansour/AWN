import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/camera/camera_session.dart';
import '../../../core/camera/input_frame.dart';
import '../../../core/voice/feature_voice_command_service.dart';
import '../controllers/object_identifier_controller.dart';

class ObjectIdentifierCameraScreen extends StatefulWidget {
  const ObjectIdentifierCameraScreen({super.key});

  @override
  State<ObjectIdentifierCameraScreen> createState() =>
      _ObjectIdentifierCameraScreenState();
}

class _ObjectIdentifierCameraScreenState
    extends State<ObjectIdentifierCameraScreen> {
  final ObjectIdentifierController _controller = ObjectIdentifierController();

  final FeatureVoiceCommandService _voiceCommands = FeatureVoiceCommandService(
    debugName: 'object_identifier',
  );

  static const List<FeatureVoiceCommand> _captureAndExitCommands = [
    FeatureVoiceCommand(
      id: FeatureVoiceCommandIds.start,
      phrases: ['تصوير', 'صور', 'صورة', 'صوره'],
    ),
    FeatureVoiceCommand(
      id: FeatureVoiceCommandIds.exit,
      phrases: ['اغلاق', 'إغلاق', 'غلق', 'اغلق', 'إغلق'],
    ),
  ];

  static const List<FeatureVoiceCommand> _exitOnlyCommands = [
    FeatureVoiceCommand(
      id: FeatureVoiceCommandIds.exit,
      phrases: ['اغلاق', 'إغلاق', 'غلق', 'اغلق', 'إغلق'],
    ),
  ];

  bool _closing = false;
  bool _voiceStarted = false;
  bool _analysisRunning = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initFeature());
  }

  Future<void> _initFeature() async {
    await _controller.init();

    if (!mounted || _closing) return;

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
          if (_analysisRunning || _controller.uiState.isBusy) return;

          _voiceCommands.replaceCommands(_exitOnlyCommands);

          unawaited(_runCaptureCommand());
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

  Future<void> _captureFromAnywhere() async {
    if (_closing) return;

    if (_controller.uiState.isBusy) return;

    if (_analysisRunning && !_controller.uiState.isBusy) {
      _analysisRunning = false;
    }

    _voiceCommands.replaceCommands(_exitOnlyCommands);

    await _runCaptureCommand();
  }

  Future<void> _runCaptureCommand() async {
    if (_closing) return;
    if (_analysisRunning || _controller.uiState.isBusy) return;

    _analysisRunning = true;

    _voiceCommands.replaceCommands(_exitOnlyCommands);

    await _voiceCommands.resume(after: const Duration(milliseconds: 120));

    await _controller.captureAndAnalyze(
      pauseVoiceForSpeech: () async {
        await _voiceCommands.pause();
      },
      resumeVoiceForAnalysis: () async {
        if (!mounted || _closing) return;

        _voiceCommands.replaceCommands(_exitOnlyCommands);

        await _voiceCommands.resume(after: const Duration(milliseconds: 120));
      },
      onReadyForNextCapture: _enableCaptureAgainImmediately,
    );

    if (!mounted || _closing) {
      _analysisRunning = false;
      return;
    }

    await _enableCaptureAgainImmediately();
  }

  Future<void> _enableCaptureAgainImmediately() async {
    if (!mounted || _closing) return;

    _analysisRunning = false;

    _voiceCommands.replaceCommands(_captureAndExitCommands);

    await _voiceCommands.resume(after: const Duration(milliseconds: 60));
  }

  Future<void> _exitToHome() async {
    if (_closing) return;

    _closing = true;

    await _voiceCommands.stop();

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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF020711),
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: _captureFromAnywhere,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final state = _controller.uiState;

                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF06162A),
                        Color(0xFF020711),
                        Color(0xFF01040A),
                      ],
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact =
                          constraints.maxHeight < 760 ||
                          constraints.maxWidth < 390;

                      final double innerHeight = (constraints.maxHeight - 24)
                          .toDouble();

                      final double topBarHeight = compact ? 52 : 56;
                      final double gapAfterTitle = compact ? 10 : 12;
                      final double gapBetweenSections = compact ? 10 : 12;

                      final double resultHeight = (innerHeight * 0.26)
                          .clamp(185.0, 220.0)
                          .toDouble();

                      final double cameraHeight =
                          (innerHeight -
                                  topBarHeight -
                                  gapAfterTitle -
                                  gapBetweenSections -
                                  resultHeight)
                              .clamp(310.0, 590.0)
                              .toDouble();

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          children: [
                            SizedBox(
                              height: topBarHeight,
                              child: _TopBar(
                                title: 'معرفة الأشياء',
                                onBack: () => unawaited(_exitToHome()),
                              ),
                            ),
                            SizedBox(height: gapAfterTitle),
                            SizedBox(
                              height: cameraHeight,
                              width: double.infinity,
                              child: state.isCameraAllowed
                                  ? CameraSession(
                                      minFrameInterval: const Duration(
                                        milliseconds: 250,
                                      ),
                                      onFrame: (InputFrame frame) async {
                                        await _controller.onFrame(frame);
                                      },
                                      onSessionReady: _controller.attachSession,
                                      builder: (context, preview) {
                                        return _ObjectCameraFrame(
                                          preview: preview,
                                          isBusy: state.isBusy,
                                          onCapture: _captureFromAnywhere,
                                        );
                                      },
                                    )
                                  : _PermissionOrLoadingBox(
                                      message: state.statusText,
                                      subtitle: state.subtitleText,
                                    ),
                            ),
                            SizedBox(height: gapBetweenSections),
                            SizedBox(
                              height: resultHeight,
                              width: double.infinity,
                              child: _ResultCard(
                                statusText: state.statusText,
                                titleText: state.titleText,
                                subtitleText: state.subtitleText,
                                actionText: state.actionText,
                                confidenceText:
                                    state.result?.confidenceText ?? '',
                                isBusy: state.isBusy,
                                isActionEnabled: state.isListenEnabled,
                                onListen: _controller.speakCurrentResult,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _TopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _ObjectCameraFrame extends StatelessWidget {
  final Widget preview;
  final bool isBusy;
  final Future<void> Function() onCapture;

  const _ObjectCameraFrame({
    required this.preview,
    required this.isBusy,
    required this.onCapture,
  });

  static const Color _accent = Color(0xFF35A7FF);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Stack(
        children: [
          Positioned.fill(child: preview),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _accent.withValues(alpha: 0.85),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.06),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.34),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isBusy
                      ? 'جاري تحليل الصورة...'
                      : 'وجّه الكاميرا نحو الشيء ثم اضغط مرتين أو قل تصوير',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: 76,
                  height: 76,
                  child: ElevatedButton(
                    onPressed: isBusy ? null : onCapture,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: _accent,
                      disabledBackgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 10,
                      shadowColor: _accent.withValues(alpha: 0.36),
                    ),
                    child: isBusy
                        ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt_rounded, size: 34),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String statusText;
  final String titleText;
  final String subtitleText;
  final String actionText;
  final String confidenceText;
  final bool isBusy;
  final bool isActionEnabled;
  final Future<void> Function() onListen;

  const _ResultCard({
    required this.statusText,
    required this.titleText,
    required this.subtitleText,
    required this.actionText,
    required this.confidenceText,
    required this.isBusy,
    required this.isActionEnabled,
    required this.onListen,
  });

  static const Color _accent = Color(0xFF35A7FF);

  String _displayStatusText() {
    final normalized = statusText.trim();

    if (normalized == 'جاهز للتجربة' || normalized == 'جاهز للتجربه') {
      return 'جاهز';
    }

    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _accent.withValues(alpha: 0.38), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.12),
            blurRadius: 26,
            spreadRadius: 1,
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF071A31), Color(0xFF041020), Color(0xFF020711)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: _accent.withValues(alpha: 0.38)),
                ),
                child: isBusy
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: _accent,
                        ),
                      )
                    : const Icon(
                        Icons.visibility_rounded,
                        color: _accent,
                        size: 23,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _displayStatusText(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (confidenceText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    confidenceText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            titleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Expanded(
            child: Text(
              subtitleText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: isActionEnabled ? onListen : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                disabledBackgroundColor: Colors.white12,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.volume_up_rounded, size: 21),
              label: Text(
                actionText,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionOrLoadingBox extends StatelessWidget {
  final String message;
  final String subtitle;

  const _PermissionOrLoadingBox({
    required this.message,
    required this.subtitle,
  });

  static const Color _accent = Color(0xFF35A7FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _accent.withValues(alpha: 0.80), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.16),
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF081321), Color(0xFF030812)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 46,
                height: 46,
                child: CircularProgressIndicator(
                  color: _accent,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
