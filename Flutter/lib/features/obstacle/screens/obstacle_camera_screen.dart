import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:myeye/core/camera/camera_session.dart';
import 'package:myeye/core/camera/input_frame.dart';
import 'package:myeye/core/voice/feature_voice_command_service.dart';
import 'package:myeye/features/obstacle/controllers/obstacle_controller.dart';
import 'package:myeye/features/obstacle/models/obstacle_ui_state.dart';
import 'package:myeye/features/obstacle/widgets/obstacle_camera_frame.dart';
import 'package:myeye/features/obstacle/widgets/obstacle_status_card.dart';

class ObstacleCameraScreen extends StatefulWidget {
  const ObstacleCameraScreen({super.key});

  @override
  State<ObstacleCameraScreen> createState() => _ObstacleCameraScreenState();
}

class _ObstacleCameraScreenState extends State<ObstacleCameraScreen> {
  late final ObstacleController _controller;
  late final FeatureVoiceCommandService _voiceCommands;

  static const Color _bgTop = Color(0xFF03111D);
  static const Color _bgMiddle = Color(0xFF020A13);
  static const Color _bgBottom = Color(0xFF031321);

  static const Color _neon = Color(0xFF1EF7FF);
  static const Color _glass = Color(0xEA031522);
  static const Color _mutedText = Color(0xFFD0FBFF);

  static const List<FeatureVoiceCommand> _startOnlyCommands = [
    FeatureVoiceCommand(id: FeatureVoiceCommandIds.start, phrases: ['تصوير']),
  ];

  bool _closing = false;
  bool _voiceStarted = false;

  @override
  void initState() {
    super.initState();

    _controller = ObstacleController();
    _voiceCommands = FeatureVoiceCommandService(debugName: 'obstacle');

    unawaited(_initFeature());
  }

  Future<void> _initFeature() async {
    /*
      المطلوب:
      - أول ما الشاشة تفتح، الجملة الصوتية تشتغل.
      - بعدها المايك يشتغل فقط لسماع كلمة "تصوير".
      - أول ما الكشف يبدأ، المايك يتقفل نهائيًا.
      - أثناء الكشف، الخروج يكون Double Tap فقط.
    */
    await _controller.init();

    if (!mounted || _closing) return;

    if (!_controller.uiState.canStartCamera) return;

    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted || _closing) return;

    await _startVoiceCommands();
  }

  Future<void> _startVoiceCommands() async {
    if (_voiceStarted || _closing) return;

    if (_controller.uiState.scanning) return;

    _voiceStarted = true;

    final started = await _voiceCommands.start(
      commands: _startOnlyCommands,
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 30),
      onCommand: (commandId, _) async {
        if (!mounted || _closing) return;

        if (commandId == FeatureVoiceCommandIds.start) {
          if (_controller.uiState.scanning) return;

          await _stopVoiceCommands();

          if (!mounted || _closing) return;

          await _controller.toggleScanning();

          if (!mounted || _closing) return;

          /*
            تأكيد زيادة:
            بعد بداية كشف العوائق، المايك لازم يفضل مقفول
            عشان ما يعملش صوت تشغيل/إيقاف وما يأثرش على تحذيرات العوائق.
          */
          await _stopVoiceCommands();

          return;
        }
      },
    );

    if (!started) {
      _voiceStarted = false;
    }
  }

  Future<void> _stopVoiceCommands() async {
    if (!_voiceStarted) return;

    try {
      await _voiceCommands.stop();
    } catch (_) {}

    _voiceStarted = false;
  }

  Future<void> _handleDoubleTap() async {
    if (_closing) return;

    if (_controller.uiState.scanning) {
      await _exitToHome();
      return;
    }

    await _stopVoiceCommands();

    if (!mounted || _closing) return;

    await _controller.toggleScanning();

    if (!mounted || _closing) return;

    await _stopVoiceCommands();
  }

  Future<void> _exitToHome() async {
    if (_closing) return;

    _closing = true;

    await _stopVoiceCommands();
    await _controller.closeForExit();

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    unawaited(_voiceCommands.dispose());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: _handleDoubleTap,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: _bgBottom,
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final state = _controller.uiState;

              return Scaffold(
                backgroundColor: _bgBottom,
                body: state.canStartCamera
                    ? CameraSession(
                        onFrame: (InputFrame frame) =>
                            _controller.onFrame(frame),
                        minFrameInterval: const Duration(
                          milliseconds: ObstacleController.frameIntervalMs,
                        ),
                        resolutionPreset: ResolutionPreset.medium,
                        onSessionReady: _controller.attachSession,
                        builder: (context, preview) {
                          return _buildPage(
                            state: state,
                            preview: preview,
                            cameraIsLive: true,
                          );
                        },
                      )
                    : _buildPage(
                        state: state,
                        preview: _buildLoadingPreview(state),
                        cameraIsLive: false,
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPage({
    required ObstacleUiState state,
    required Widget preview,
    required bool cameraIsLive,
  }) {
    final accent = _accentForState(state);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.50, 1.0],
          colors: [_bgTop, _bgMiddle, _bgBottom],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: _backgroundGlow()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxHeight < 720 || constraints.maxWidth < 390;

                final double topBarHeight = compact ? 52 : 56;
                final double gapAfterTitle = compact ? 10 : 12;
                final double statusHeight = compact ? 138 : 150;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 16 : 18,
                    8,
                    compact ? 16 : 18,
                    compact ? 14 : 16,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: topBarHeight,
                        child: _TopBar(
                          title: 'كشف العوائق',
                          onBack: () => unawaited(_exitToHome()),
                        ),
                      ),
                      SizedBox(height: gapAfterTitle),
                      Expanded(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              bottom: statusHeight - 16,
                              child: ObstacleCameraFrame(
                                preview: preview,
                                cameraIsLive: cameraIsLive,
                                scanning: state.scanning,
                                statusText: _cameraStatus(state, cameraIsLive),
                                detections: state.detections,
                                primaryColor: accent,
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: ObstacleStatusCard(
                                state: state,
                                primaryColor: accent,
                                glassColor: _glass,
                                mutedText: _mutedText,
                                compact: compact,
                              ),
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
        ],
      ),
    );
  }

  Widget _backgroundGlow() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            bottom: -130,
            left: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _neon.withValues(alpha: 0.045),
                boxShadow: [
                  BoxShadow(
                    color: _neon.withValues(alpha: 0.11),
                    blurRadius: 90,
                    spreadRadius: 28,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPreview(ObstacleUiState state) {
    final isError =
        state.status.contains('خطأ') || state.status.contains('محتاج');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _glass,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: _neon.withValues(alpha: 0.75),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _neon.withValues(alpha: 0.22),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  color: isError ? Colors.redAccent : _neon,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                state.status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                state.guide,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _mutedText,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _cameraStatus(ObstacleUiState state, bool cameraIsLive) {
    if (!cameraIsLive) return state.status;
    if (!state.scanning) return 'جاهز';
    if (state.warning?.urgent == true) return 'تحذير';
    return 'يفحص الطريق';
  }

  Color _accentForState(ObstacleUiState state) => _neon;
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
