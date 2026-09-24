import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'app_colors.dart';
import 'widgets/glass.dart';
import 'widgets/custom_icons.dart';

/// What VoiceScreen hands back: the recognized text, and whether the caller
/// should send it immediately or just drop it into the input field.
class VoiceResult {
  final String text;
  final bool autoSend;
  const VoiceResult(this.text, {this.autoSend = false});
}

/// Full-screen "listening" experience. Pop this screen with a VoiceResult
/// via Navigator.pop(context, VoiceResult(text, autoSend: ...)).
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  late final AnimationController _ringController;

  bool _speechAvailable = false;
  bool _isListening = false;
  String _recognized = '';
  String _caption = "Go ahead, I'm listening…";

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          setState(() {
            _isListening = false;
            _caption = 'Didn\'t catch that — tap the mic to try again.';
          });
        },
      );
      setState(() {
        _speechAvailable = available;
        _caption = available ? "Go ahead, I'm listening…" : 'Speech recognition isn\'t available on this device.';
      });
      if (available) _startListening();
    } catch (_) {
      setState(() {
        _speechAvailable = false;
        _caption = 'Speech recognition isn\'t set up yet.';
      });
    }
  }

  void _startListening() async {
    if (!_speechAvailable || _isListening) return;
    setState(() {
      _isListening = true;
      _caption = "Go ahead, I'm listening…";
    });
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _recognized = result.recognizedWords;
          if (result.finalResult) _caption = 'Tap the check to use this, or the mic to redo it.';
        });
      },
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  void dispose() {
    _ringController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: AppColors.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    GlassIconButton(
                      icon: const AppIcon(AppGlyph.back, color: AppColors.textDark, size: 18),
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 14),
                    const Text('Voice Assessment',
                        style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Caption + ring: centered, and scrollable if the screen is short.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  _recognized.isNotEmpty ? _recognized : _caption,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 15, height: 1.5),
                                ),
                              ),
                              const SizedBox(height: 36),
                              SizedBox(
                                width: 260,
                                height: 260,
                                child: AnimatedBuilder(
                                  animation: _ringController,
                                  builder: (context, _) {
                                    return CustomPaint(
                                      painter: _RingPainter(
                                        rotation: _ringController.value * 2 * math.pi,
                                        active: _isListening,
                                      ),
                                      child: Center(
                                        child: GestureDetector(
                                          onTap: _isListening ? _stopListening : _startListening,
                                          child: Container(
                                            width: 84,
                                            height: 84,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(colors: AppColors.accentGradient),
                                            ),
                                            child: Center(
                                              child: AppIcon(
                                                _isListening ? AppGlyph.waveform : AppGlyph.mic,
                                                color: Colors.white,
                                                size: 30,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GlassIconButton(
                      icon: const AppIcon(AppGlyph.edit, color: AppColors.textDark, size: 18),
                      onTap: () {
                        Navigator.pop(context, VoiceResult(_recognized));
                      },
                    ),
                    GlassGradientButton(
                      onTap: _recognized.trim().isEmpty
                          ? null
                          : () => Navigator.pop(context, VoiceResult(_recognized)),
                      child: const Text('Use this',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    // Sends the recognized text straight into the chat, no extra tap needed.
                    GestureDetector(
                      onTap: _recognized.trim().isEmpty
                          ? null
                          : () => Navigator.pop(context, VoiceResult(_recognized, autoSend: true)),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _recognized.trim().isEmpty
                                ? [AppColors.glassFillStrong, AppColors.glassFillStrong]
                                : AppColors.accentGradient,
                          ),
                        ),
                        child: const Center(
                          child: AppIcon(AppGlyph.send, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double rotation;
  final bool active;

  _RingPainter({required this.rotation, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Soft outer glow
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        AppColors.accent.withOpacity(active ? 0.30 : 0.16),
        AppColors.accent.withOpacity(0.0),
      ]).createShader(Rect.fromCircle(center: center, radius: radius + 30));
    canvas.drawCircle(center, radius + 30, glow);

    // Rotating iridescent ring
    final sweep = SweepGradient(
      colors: AppColors.voiceRing,
      transform: GradientRotation(rotation),
    );
    final ringPaint = Paint()
      ..shader = sweep.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 14 : 9
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, ringPaint);

    // Inner dark disc so the mic button sits on a flat surface
    canvas.drawCircle(center, radius - 20, Paint()..color = AppColors.backgroundDeep.withOpacity(0.85));
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.active != active;
}
