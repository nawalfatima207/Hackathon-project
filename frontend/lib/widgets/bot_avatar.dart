import 'package:flutter/material.dart';
import '../app_colors.dart';

/// An original, simply-shaped robot mascot painted with CustomPaint —
/// rounded head/body, glowing eyes, a small antenna. Purely geometric,
/// not a reproduction of any existing character or artwork.
class BotAvatar extends StatefulWidget {
  final double size;
  final bool listening;

  const BotAvatar({super.key, this.size = 140, this.listening = false});

  @override
  State<BotAvatar> createState() => _BotAvatarState();
}

class _BotAvatarState extends State<BotAvatar> with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));

    _scheduleBlink();
  }

  void _scheduleBlink() async {
    while (mounted) {
      await Future.delayed(Duration(milliseconds: 2400 + (400 * (DateTime.now().millisecond % 5))));
      if (!mounted) return;
      await _blinkController.forward();
      await _blinkController.reverse();
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatController, _blinkController]),
      builder: (context, _) {
        final floatOffset = (_floatController.value - 0.5) * 10;
        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _BotPainter(
              blink: _blinkController.value,
              listening: widget.listening,
            ),
          ),
        );
      },
    );
  }
}

class _BotPainter extends CustomPainter {
  final double blink;
  final bool listening;

  _BotPainter({required this.blink, required this.listening});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final center = Offset(w / 2, h / 2);

    // Soft glow behind the bot
    final glowPaint = Paint()
      ..shader = RadialGradient(colors: [
        AppColors.accent.withOpacity(listening ? 0.35 : 0.20),
        AppColors.accent.withOpacity(0.0),
      ]).createShader(Rect.fromCircle(center: center, radius: w * 0.62));
    canvas.drawCircle(center, w * 0.62, glowPaint);

    // Antenna
    final antennaPaint = Paint()
      ..color = AppColors.accentSoft
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.5, h * 0.14), Offset(w * 0.5, h * 0.05), antennaPaint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.04), w * 0.025,
        Paint()..color = AppColors.magenta);

    // Body (rounded rect, metallic gradient)
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.72), width: w * 0.5, height: h * 0.28),
      Radius.circular(w * 0.14),
    );
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEDE9FE), Color(0xFFC9B8F5)],
      ).createShader(bodyRect.outerRect);
    canvas.drawRRect(bodyRect, bodyPaint);

    // Head (rounded rect, metallic gradient)
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.40), width: w * 0.64, height: h * 0.44),
      Radius.circular(w * 0.22),
    );
    final headPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Color(0xFFE3D9FB)],
      ).createShader(headRect.outerRect);
    canvas.drawRRect(headRect, headPaint);

    // Face plate (darker inset panel)
    final faceRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.42), width: w * 0.48, height: h * 0.26),
      Radius.circular(w * 0.12),
    );
    canvas.drawRRect(faceRect, Paint()..color = AppColors.backgroundDeep.withOpacity(0.92));

    // Eyes — glowing, with a blink (squash vertically)
    final eyeH = h * 0.07 * (1 - blink * 0.85);
    final eyePaint = Paint()
      ..color = listening ? AppColors.teal : AppColors.accentSoft
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final eyeCorePaint = Paint()..color = listening ? AppColors.teal : Colors.white;

    for (final dx in [-0.11, 0.11]) {
      final eyeCenter = Offset(w * (0.5 + dx), h * 0.42);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: eyeCenter, width: w * 0.09, height: eyeH),
          Radius.circular(w * 0.05),
        ),
        eyePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: eyeCenter, width: w * 0.05, height: eyeH * 0.7),
          Radius.circular(w * 0.03),
        ),
        eyeCorePaint,
      );
    }

    // Side ear nubs
    final earPaint = Paint()..color = const Color(0xFFC9B8F5);
    canvas.drawCircle(Offset(w * 0.16, h * 0.40), w * 0.035, earPaint);
    canvas.drawCircle(Offset(w * 0.84, h * 0.40), w * 0.035, earPaint);

    // Little chest light
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.72),
      w * 0.035,
      Paint()..color = listening ? AppColors.teal : AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(covariant _BotPainter oldDelegate) =>
      oldDelegate.blink != blink || oldDelegate.listening != listening;
}
