import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:myeye/core/camera/camera_session.dart';
import 'package:myeye/core/camera/input_frame.dart';
import 'package:myeye/core/constants/app_constants.dart';
import 'package:myeye/core/voice/feature_voice_command_service.dart';
import 'package:myeye/features/currency/controllers/currency_controller.dart';
import 'package:myeye/features/currency/models/currency_session_state.dart';
import 'package:myeye/features/currency/models/currency_ui_state.dart';
import 'package:myeye/features/currency/widgets/currency_bottom_hint.dart';
import 'package:myeye/features/currency/widgets/currency_camera_frame.dart';
import 'package:myeye/features/currency/widgets/currency_result_card.dart';
import 'package:myeye/features/currency/widgets/currency_top_bar.dart';

class CurrencyCameraScreen extends StatefulWidget {
  const CurrencyCameraScreen({super.key});

  @override
  State<CurrencyCameraScreen> createState() => _CurrencyCameraScreenState();
}

class _CurrencyCameraScreenState extends State<CurrencyCameraScreen> {
  late final CurrencyController _controller;
  late final FeatureVoiceCommandService _voiceCommands;

  static const Color _bgTop = Color(0xFF03111E);
  static const Color _bgBottom = Color(0xFF020814);
  static const Color _primaryGreen = Color(0xFF26FF74);
  static const Color _softGreen = Color(0xFF0B3D34);
  static const Color _glass = Color(0xCC061624);
  static const Color _glassDeep = Color(0xF003101D);
  static const Color _mutedText = Color(0xFFC6CED5);

  static const List<FeatureVoiceCommand> _currencyStartOnly = [
    FeatureVoiceCommand(id: FeatureVoiceCommandIds.start, phrases: ['تصوير']),
  ];

  static const List<FeatureVoiceCommand> _currencyExitOnly = [
    FeatureVoiceCommand(
      id: FeatureVoiceCommandIds.exit,
      phrases: ['اغلاق', 'إغلاق'],
    ),
  ];

  static const List<FeatureVoiceCommand> _currencyStartAndExit = [
    ..._currencyStartOnly,
    ..._currencyExitOnly,
  ];

  bool _closing = false;
  bool _voiceStarted = false;
  bool _controllerDisposed = false;

  CurrencySessionState _lastSessionForVoice = CurrencySessionState.idle;

  @override
  void initState() {
    super.initState();

    _controller = CurrencyController();
    _voiceCommands = FeatureVoiceCommandService(debugName: 'currency');

    _controller.setVoiceLifecycleHooks(
      pauseVoiceForFinalSpeech: () async {
        await _voiceCommands.pause();
      },
      resumeVoiceAfterFinalSpeech: () async {
        if (!mounted || _closing || !_voiceStarted) return;

        _voiceCommands.replaceCommands(_currencyStartAndExit);

        await _voiceCommands.resume(after: const Duration(milliseconds: 60));
      },
    );

    _controller.addListener(_syncVoiceCommandsWithSessionState);

    unawaited(_initFeature());
  }

  Future<void> _initFeature() async {
    /*
      أول ما الفيتشر يفتح:
      - التطبيق يتكلم والمايك قافل.
      - بعد ما الكلام يخلص، المايك يشتغل.
    */
    await _controller.init();

    if (!mounted || _closing) return;
    if (!_controller.uiState.canStartCamera) return;

    await Future.delayed(const Duration(milliseconds: 180));

    if (!mounted || _closing) return;

    await _startVoiceCommands();
  }

  Future<void> _startVoiceCommands() async {
    if (_voiceStarted || _closing) return;

    _voiceStarted = true;

    final started = await _voiceCommands.start(
      commands: _controller.uiState.sessionState == CurrencySessionState.idle
          ? _currencyStartAndExit
          : _currencyExitOnly,
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 12),
      onCommand: (commandId, _) async {
        if (!mounted || _closing) return;

        if (commandId == FeatureVoiceCommandIds.start) {
          if (_controller.uiState.sessionState != CurrencySessionState.idle) {
            return;
          }

          /*
            بعد كلمة تصوير:
            يبدأ التحليل، والمايك يفضل شغال لكن إغلاق فقط.
          */
          _voiceCommands.replaceCommands(_currencyExitOnly);

          await _controller.startDetection();

          if (!mounted || _closing) return;

          await _voiceCommands.resume(after: const Duration(milliseconds: 80));

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

  void _syncVoiceCommandsWithSessionState() {
    if (_closing || !_voiceStarted) return;

    final currentSession = _controller.uiState.sessionState;

    if (currentSession == _lastSessionForVoice) return;

    _lastSessionForVoice = currentSession;

    final isIdle = currentSession == CurrencySessionState.idle;

    _voiceCommands.replaceCommands(
      isIdle ? _currencyStartAndExit : _currencyExitOnly,
    );

    /*
      أثناء التحليل:
      المايك شغال إغلاق فقط.

      بعد جملة "لكشف عملة أخرى..." controller hook بيرجع المايك فورًا.
      وبرضه هنا بنضمن إن أي رجوع idle يشغل المايك بسرعة.
    */
    unawaited(
      _voiceCommands.resume(
        after: isIdle
            ? const Duration(milliseconds: 60)
            : const Duration(milliseconds: 120),
      ),
    );
  }

  Future<void> _handleDoubleTap() async {
    if (_closing) return;

    if (_controller.uiState.sessionState != CurrencySessionState.idle) {
      return;
    }

    _voiceCommands.replaceCommands(_currencyExitOnly);

    await _controller.startDetection();

    if (!mounted || _closing) return;

    await _voiceCommands.resume(after: const Duration(milliseconds: 80));
  }

  Future<void> _exitToHome() async {
    if (_closing) return;

    _closing = true;

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
    _controller.removeListener(_syncVoiceCommandsWithSessionState);

    unawaited(_voiceCommands.dispose());
    unawaited(_controller.disposeController());

    if (!_controllerDisposed) {
      _controllerDisposed = true;
      _controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleSystemBack,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: _handleDoubleTap,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final uiState = _controller.uiState;

                return Scaffold(
                  backgroundColor: _bgBottom,
                  body: uiState.canStartCamera
                      ? CameraSession(
                          onFrame: (InputFrame frame) =>
                              _controller.onFrame(frame),
                          minFrameInterval: const Duration(
                            milliseconds: CurrencyConstants.frameIntervalMs,
                          ),
                          resolutionPreset: ResolutionPreset.medium,
                          onSessionReady: _controller.attachSession,
                          builder: (context, preview) {
                            return _buildPage(
                              uiState: uiState,
                              preview: preview,
                              cameraIsLive: true,
                            );
                          },
                        )
                      : _buildPage(
                          uiState: uiState,
                          preview: _buildLoadingPreview(uiState),
                          cameraIsLive: false,
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage({
    required CurrencyUiState uiState,
    required Widget preview,
    required bool cameraIsLive,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgBottom],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 160,
              left: -100,
              child: _buildGlowCircle(210, Colors.cyan.withValues(alpha: 0.08)),
            ),
            Column(
              children: [
                const CurrencyTopBar(),
                const SizedBox(height: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxHeight < 670;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: CurrencyCameraFrame(
                                preview: preview,
                                cameraIsLive: cameraIsLive,
                                statusText: _topStatusText(
                                  uiState: uiState,
                                  cameraIsLive: cameraIsLive,
                                ),
                                primaryGreen: _primaryGreen,
                              ),
                            ),
                            Positioned(
                              left: compact ? 16 : 18,
                              right: compact ? 16 : 18,
                              bottom: compact ? 54 : 58,
                              child: CurrencyResultCard(
                                label: _visibleCurrencyLabel(uiState),
                                guideText: _cardGuideText(uiState),
                                confidenceText: _confidenceText(uiState),
                                primaryGreen: _primaryGreen,
                                softGreen: _softGreen,
                                glass: _glass,
                                glassDeep: _glassDeep,
                                mutedText: _mutedText,
                                compact: compact,
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 8,
                              child: CurrencyBottomHint(
                                text: _bottomHintText(uiState),
                                primaryGreen: _primaryGreen,
                                mutedText: _mutedText,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingPreview(CurrencyUiState uiState) {
    final isError =
        uiState.status.contains('خطأ') || uiState.status.contains('محتاج');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: isError ? Colors.redAccent : _primaryGreen,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              uiState.status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              uiState.guide,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _mutedText,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 90, spreadRadius: 45)],
      ),
    );
  }

  String _topStatusText({
    required CurrencyUiState uiState,
    required bool cameraIsLive,
  }) {
    if (!cameraIsLive) return uiState.status;

    switch (uiState.sessionState) {
      case CurrencySessionState.idle:
        return 'جاهز';
      case CurrencySessionState.guiding:
        return 'Live';
      case CurrencySessionState.locking:
        return 'تثبيت';
      case CurrencySessionState.capturing:
        return 'تأكيد';
    }
  }

  String _visibleCurrencyLabel(CurrencyUiState uiState) {
    final value = uiState.label.trim();

    if (value.isEmpty || value == '…' || value == 'Unknown') {
      return '—';
    }

    return value;
  }

  String _cardGuideText(CurrencyUiState uiState) {
    if (!uiState.canStartCamera) return uiState.guide;

    if (uiState.sessionState == CurrencySessionState.idle &&
        _visibleCurrencyLabel(uiState) == '—') {
      return 'وجّه العملة أمام الكاميرا';
    }

    if (uiState.sessionState == CurrencySessionState.capturing) {
      return 'جاري تأكيد النتيجة';
    }

    return uiState.guide.replaceAll('…', '').trim();
  }

  String _confidenceText(CurrencyUiState uiState) {
    final visibleLabel = _visibleCurrencyLabel(uiState);

    if (visibleLabel == '—' || uiState.confidence <= 0) {
      return 'في الانتظار';
    }

    if (uiState.confidence >= 0.68) return 'ثقة عالية';
    if (uiState.confidence >= 0.52) return 'ثقة متوسطة';
    return 'ثقة منخفضة';
  }

  String _bottomHintText(CurrencyUiState uiState) {
    if (!uiState.canStartCamera) return 'انتظر تجهيز الكاميرا';

    switch (uiState.sessionState) {
      case CurrencySessionState.idle:
        return 'انقر مرتين أو قل تصوير لبدء تحديد العملة';
      case CurrencySessionState.guiding:
        return 'ثبّت العملة داخل الإطار';
      case CurrencySessionState.locking:
        return 'جاري التثبيت… حافظ على نفس الوضع';
      case CurrencySessionState.capturing:
        return 'جاري تأكيد النتيجة';
    }
  }
}
