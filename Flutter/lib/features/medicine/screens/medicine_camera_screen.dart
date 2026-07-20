import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/camera/camera_session.dart';
import '../../../core/camera/input_frame.dart';
import '../../../core/voice/feature_voice_command_service.dart';
import '../controllers/medicine_controller.dart';
import '../widgets/medicine_camera_frame.dart';
import '../widgets/medicine_result_card.dart';

class MedicineCameraScreen extends StatefulWidget {
  const MedicineCameraScreen({super.key});

  @override
  State<MedicineCameraScreen> createState() => _MedicineCameraScreenState();
}

class _MedicineCameraScreenState extends State<MedicineCameraScreen> {
  final MedicineController _controller = MedicineController();

  final FeatureVoiceCommandService _voiceCommands = FeatureVoiceCommandService(
    debugName: 'medicine',
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
    _analysisRunning = false;

    await _voiceCommands.stop();
    await _controller.disposeController();

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  Future<bool> _handleSystemBack() async {
    await _exitToHome();
    return false;
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
    return WillPopScope(
      onWillPop: _handleSystemBack,
      child: Directionality(
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
                          Color(0xFF071324),
                          Color(0xFF020711),
                          Color(0xFF01040A),
                        ],
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double innerHeight = (constraints.maxHeight - 24)
                            .toDouble();

                        const double topBarHeight = 56;
                        const double gapAfterTitle = 12;
                        const double gapBetweenSections = 12;

                        final double resultHeight = (innerHeight * 0.235)
                            .clamp(172.0, 202.0)
                            .toDouble();

                        final double cameraHeight =
                            (innerHeight -
                                    topBarHeight -
                                    gapAfterTitle -
                                    gapBetweenSections -
                                    resultHeight)
                                .clamp(300.0, 580.0)
                                .toDouble();

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Column(
                            children: [
                              SizedBox(
                                height: topBarHeight,
                                child: _TopBar(
                                  title: 'تحديد الدواء',
                                  onBack: () => unawaited(_exitToHome()),
                                ),
                              ),
                              const SizedBox(height: gapAfterTitle),
                              SizedBox(
                                height: cameraHeight,
                                width: double.infinity,
                                child: state.isCameraAllowed
                                    ? CameraSession(
                                        minFrameInterval: const Duration(
                                          milliseconds: 180,
                                        ),
                                        onFrame: (InputFrame frame) async {
                                          await _controller.onFrame(frame);
                                        },
                                        onSessionReady:
                                            _controller.attachSession,
                                        builder: (context, preview) {
                                          return MedicineCameraFrame(
                                            preview: preview,
                                            isBusy: state.isBusy,
                                            isTorchOn: state.isTorchOn,
                                            onCapture: _captureFromAnywhere,
                                            onDoubleTapCapture:
                                                _captureFromAnywhere,
                                          );
                                        },
                                      )
                                    : _PermissionOrLoadingBox(
                                        message: state.statusText,
                                        subtitle: state.subtitleText,
                                      ),
                              ),
                              const SizedBox(height: gapBetweenSections),
                              SizedBox(
                                height: resultHeight,
                                width: double.infinity,
                                child: MedicineResultCard(
                                  statusText: state.statusText,
                                  titleText: state.titleText,
                                  subtitleText: state.subtitleText,
                                  actionText: state.actionText,
                                  isBusy: state.isBusy,
                                  isActionEnabled: state.isListenEnabled,
                                  onListen: _controller.speakCurrentDetails,
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

class _PermissionOrLoadingBox extends StatelessWidget {
  final String message;
  final String subtitle;

  const _PermissionOrLoadingBox({
    required this.message,
    required this.subtitle,
  });

  static const Color _accent = Color(0xFFFF8A2B);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: _accent.withValues(alpha: 0.80), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.14),
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111827), Color(0xFF050914)],
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
