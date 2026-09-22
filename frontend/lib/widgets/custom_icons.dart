import 'package:flutter/material.dart';

/// Every icon used across the redesigned app, drawn by hand with
/// CustomPainter so nothing looks like a stock Material glyph.
enum AppGlyph {
  menu,
  bell,
  chatBubble,
  mic,
  send,
  search,
  trash,
  chevronRight,
  chevronDown,
  clock,
  edit,
  camera,
  gallery,
  sliders,
  logout,
  addChat,
  home,
  library,
  profile,
  brain,
  sparkle,
  close,
  back,
  bookmark,
  waveform,
}

class AppIcon extends StatelessWidget {
  final AppGlyph glyph;
  final double size;
  final Color color;
  final double strokeWidth;

  const AppIcon(
    this.glyph, {
    super.key,
    this.size = 20,
    this.color = Colors.white,
    this.strokeWidth = 1.8,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GlyphPainter(glyph, color, strokeWidth),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final AppGlyph glyph;
  final Color color;
  final double strokeW;

  _GlyphPainter(this.glyph, this.color, this.strokeW);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (glyph) {
      case AppGlyph.menu:
        // three asymmetric bars, off-center to look intentional
        canvas.drawLine(Offset(w * 0.18, h * 0.30), Offset(w * 0.82, h * 0.30), stroke);
        canvas.drawLine(Offset(w * 0.18, h * 0.50), Offset(w * 0.62, h * 0.50), stroke);
        canvas.drawLine(Offset(w * 0.18, h * 0.70), Offset(w * 0.74, h * 0.70), stroke);
        break;

      case AppGlyph.bell:
        final path = Path()
          ..moveTo(w * 0.5, h * 0.12)
          ..cubicTo(w * 0.28, h * 0.14, w * 0.24, h * 0.34, w * 0.24, h * 0.46)
          ..lineTo(w * 0.24, h * 0.62)
          ..lineTo(w * 0.16, h * 0.74)
          ..lineTo(w * 0.84, h * 0.74)
          ..lineTo(w * 0.76, h * 0.62)
          ..lineTo(w * 0.76, h * 0.46)
          ..cubicTo(w * 0.76, h * 0.34, w * 0.72, h * 0.14, w * 0.5, h * 0.12)
          ..close();
        canvas.drawPath(path, stroke);
        canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.5, h * 0.82), width: w * 0.18, height: w * 0.18),
            0.2, 2.7, false, stroke);
        break;

      case AppGlyph.chatBubble:
        final rrect = RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.12, h * 0.16, w * 0.76, h * 0.54), Radius.circular(w * 0.16));
        canvas.drawRRect(rrect, stroke);
        final tail = Path()
          ..moveTo(w * 0.30, h * 0.70)
          ..lineTo(w * 0.24, h * 0.86)
          ..lineTo(w * 0.44, h * 0.70)
          ..close();
        canvas.drawPath(tail, fill);
        canvas.drawCircle(Offset(w * 0.34, h * 0.43), w * 0.035, fill);
        canvas.drawCircle(Offset(w * 0.5, h * 0.43), w * 0.035, fill);
        canvas.drawCircle(Offset(w * 0.66, h * 0.43), w * 0.035, fill);
        break;

      case AppGlyph.mic:
        final capsule = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(w * 0.5, h * 0.38), width: w * 0.30, height: h * 0.48),
            Radius.circular(w * 0.15));
        canvas.drawRRect(capsule, stroke);
        canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.5, h * 0.52), width: w * 0.56, height: h * 0.42),
            0.15, 2.84, false, stroke);
        canvas.drawLine(Offset(w * 0.5, h * 0.78), Offset(w * 0.5, h * 0.88), stroke);
        canvas.drawLine(Offset(w * 0.36, h * 0.88), Offset(w * 0.64, h * 0.88), stroke);
        break;

      case AppGlyph.send:
        final path = Path()
          ..moveTo(w * 0.16, h * 0.52)
          ..lineTo(w * 0.84, h * 0.18)
          ..lineTo(w * 0.60, h * 0.86)
          ..lineTo(w * 0.46, h * 0.58)
          ..close();
        canvas.drawPath(path, fill);
        break;

      case AppGlyph.search:
        canvas.drawCircle(Offset(w * 0.42, h * 0.42), w * 0.26, stroke);
        canvas.drawLine(Offset(w * 0.62, h * 0.62), Offset(w * 0.84, h * 0.84), stroke);
        break;

      case AppGlyph.trash:
        canvas.drawLine(Offset(w * 0.22, h * 0.30), Offset(w * 0.78, h * 0.30), stroke);
        final body = RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.30, h * 0.30, w * 0.40, h * 0.52), Radius.circular(w * 0.05));
        canvas.drawRRect(body, stroke);
        canvas.drawLine(Offset(w * 0.40, h * 0.14), Offset(w * 0.60, h * 0.14), stroke);
        canvas.drawLine(Offset(w * 0.40, h * 0.14), Offset(w * 0.36, h * 0.30), stroke);
        canvas.drawLine(Offset(w * 0.60, h * 0.14), Offset(w * 0.64, h * 0.30), stroke);
        canvas.drawLine(Offset(w * 0.42, h * 0.40), Offset(w * 0.42, h * 0.70), stroke);
        canvas.drawLine(Offset(w * 0.58, h * 0.40), Offset(w * 0.58, h * 0.70), stroke);
        break;

      case AppGlyph.chevronRight:
        canvas.drawLine(Offset(w * 0.38, h * 0.22), Offset(w * 0.68, h * 0.5), stroke);
        canvas.drawLine(Offset(w * 0.68, h * 0.5), Offset(w * 0.38, h * 0.78), stroke);
        break;

      case AppGlyph.chevronDown:
        canvas.drawLine(Offset(w * 0.22, h * 0.38), Offset(w * 0.5, h * 0.66), stroke);
        canvas.drawLine(Offset(w * 0.5, h * 0.66), Offset(w * 0.78, h * 0.38), stroke);
        break;

      case AppGlyph.clock:
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.36, stroke);
        canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.5, h * 0.28), stroke);
        canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.66, h * 0.58), stroke);
        break;

      case AppGlyph.edit:
        final path = Path()
          ..moveTo(w * 0.22, h * 0.78)
          ..lineTo(w * 0.28, h * 0.56)
          ..lineTo(w * 0.64, h * 0.20)
          ..lineTo(w * 0.80, h * 0.36)
          ..lineTo(w * 0.44, h * 0.72)
          ..close();
        canvas.drawPath(path, stroke);
        canvas.drawLine(Offset(w * 0.22, h * 0.78), Offset(w * 0.28, h * 0.56), stroke);
        break;

      case AppGlyph.camera:
        final body = RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.14, h * 0.32, w * 0.72, h * 0.48), Radius.circular(w * 0.08));
        canvas.drawRRect(body, stroke);
        canvas.drawPath(
            Path()
              ..moveTo(w * 0.36, h * 0.32)
              ..lineTo(w * 0.42, h * 0.20)
              ..lineTo(w * 0.58, h * 0.20)
              ..lineTo(w * 0.64, h * 0.32),
            stroke);
        canvas.drawCircle(Offset(w * 0.5, h * 0.56), w * 0.16, stroke);
        break;

      case AppGlyph.gallery:
        final frame = RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.14, h * 0.18, w * 0.72, h * 0.64), Radius.circular(w * 0.08));
        canvas.drawRRect(frame, stroke);
        canvas.drawCircle(Offset(w * 0.34, h * 0.38), w * 0.07, stroke);
        canvas.drawPath(
            Path()
              ..moveTo(w * 0.18, h * 0.72)
              ..lineTo(w * 0.42, h * 0.48)
              ..lineTo(w * 0.58, h * 0.62)
              ..lineTo(w * 0.70, h * 0.50)
              ..lineTo(w * 0.84, h * 0.64),
            stroke);
        break;

      case AppGlyph.sliders:
        for (final dx in [0.28, 0.5, 0.72]) {
          canvas.drawLine(Offset(w * dx, h * 0.16), Offset(w * dx, h * 0.84), stroke);
        }
        canvas.drawCircle(Offset(w * 0.28, h * 0.36), w * 0.07, fill);
        canvas.drawCircle(Offset(w * 0.5, h * 0.62), w * 0.07, fill);
        canvas.drawCircle(Offset(w * 0.72, h * 0.30), w * 0.07, fill);
        break;

      case AppGlyph.logout:
        final door = RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.18, h * 0.16, w * 0.32, h * 0.68), Radius.circular(w * 0.04));
        canvas.drawRRect(door, stroke);
        canvas.drawLine(Offset(w * 0.40, h * 0.5), Offset(w * 0.84, h * 0.5), stroke);
        canvas.drawLine(Offset(w * 0.84, h * 0.5), Offset(w * 0.68, h * 0.36), stroke);
        canvas.drawLine(Offset(w * 0.84, h * 0.5), Offset(w * 0.68, h * 0.64), stroke);
        break;

      case AppGlyph.addChat:
        final rrect = RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.12, h * 0.18, w * 0.76, h * 0.52), Radius.circular(w * 0.16));
        canvas.drawRRect(rrect, stroke);
        final tail = Path()
          ..moveTo(w * 0.30, h * 0.70)
          ..lineTo(w * 0.24, h * 0.86)
          ..lineTo(w * 0.44, h * 0.70)
          ..close();
        canvas.drawPath(tail, fill);
        canvas.drawLine(Offset(w * 0.5, h * 0.32), Offset(w * 0.5, h * 0.52), stroke);
        canvas.drawLine(Offset(w * 0.40, h * 0.42), Offset(w * 0.60, h * 0.42), stroke);
        break;

      case AppGlyph.home:
        final path = Path()
          ..moveTo(w * 0.16, h * 0.52)
          ..lineTo(w * 0.5, h * 0.18)
          ..lineTo(w * 0.84, h * 0.52)
          ..lineTo(w * 0.84, h * 0.84)
          ..lineTo(w * 0.16, h * 0.84)
          ..close();
        canvas.drawPath(path, stroke);
        canvas.drawLine(Offset(w * 0.40, h * 0.84), Offset(w * 0.40, h * 0.60), stroke);
        canvas.drawLine(Offset(w * 0.40, h * 0.60), Offset(w * 0.60, h * 0.60), stroke);
        canvas.drawLine(Offset(w * 0.60, h * 0.60), Offset(w * 0.60, h * 0.84), stroke);
        break;

      case AppGlyph.library:
        for (final i in [0, 1, 2, 3]) {
          final dx = w * (0.18 + i * 0.18);
          final hh = h * (0.5 + (i.isEven ? 0.16 : 0.0));
          canvas.drawLine(Offset(dx, h * 0.82), Offset(dx, h * 0.82 - hh), stroke);
        }
        canvas.drawLine(Offset(w * 0.12, h * 0.82), Offset(w * 0.88, h * 0.82), stroke);
        break;

      case AppGlyph.profile:
        canvas.drawCircle(Offset(w * 0.5, h * 0.36), w * 0.18, stroke);
        canvas.drawArc(Rect.fromLTWH(w * 0.18, h * 0.54, w * 0.64, h * 0.4), 3.34, 2.75, false, stroke);
        break;

      case AppGlyph.brain:
        canvas.drawCircle(Offset(w * 0.38, h * 0.42), w * 0.2, stroke);
        canvas.drawCircle(Offset(w * 0.62, h * 0.42), w * 0.2, stroke);
        canvas.drawArc(Rect.fromLTWH(w * 0.22, h * 0.4, w * 0.56, h * 0.34), 0, 3.14, false, stroke);
        canvas.drawLine(Offset(w * 0.5, h * 0.24), Offset(w * 0.5, h * 0.7), stroke);
        break;

      case AppGlyph.sparkle:
        final path = Path()
          ..moveTo(w * 0.5, h * 0.10)
          ..lineTo(w * 0.58, h * 0.42)
          ..lineTo(w * 0.90, h * 0.5)
          ..lineTo(w * 0.58, h * 0.58)
          ..lineTo(w * 0.5, h * 0.90)
          ..lineTo(w * 0.42, h * 0.58)
          ..lineTo(w * 0.10, h * 0.5)
          ..lineTo(w * 0.42, h * 0.42)
          ..close();
        canvas.drawPath(path, fill);
        break;

      case AppGlyph.close:
        canvas.drawLine(Offset(w * 0.24, h * 0.24), Offset(w * 0.76, h * 0.76), stroke);
        canvas.drawLine(Offset(w * 0.76, h * 0.24), Offset(w * 0.24, h * 0.76), stroke);
        break;

      case AppGlyph.back:
        canvas.drawLine(Offset(w * 0.66, h * 0.20), Offset(w * 0.34, h * 0.5), stroke);
        canvas.drawLine(Offset(w * 0.34, h * 0.5), Offset(w * 0.66, h * 0.80), stroke);
        break;

      case AppGlyph.bookmark:
        final path = Path()
          ..moveTo(w * 0.28, h * 0.14)
          ..lineTo(w * 0.72, h * 0.14)
          ..lineTo(w * 0.72, h * 0.88)
          ..lineTo(w * 0.5, h * 0.68)
          ..lineTo(w * 0.28, h * 0.88)
          ..close();
        canvas.drawPath(path, stroke);
        break;

      case AppGlyph.waveform:
        final bars = [0.3, 0.55, 0.85, 0.5, 0.7, 0.35, 0.6];
        for (var i = 0; i < bars.length; i++) {
          final dx = w * (0.1 + i * 0.13);
          final barH = h * bars[i];
          canvas.drawLine(Offset(dx, h * 0.5 - barH / 2), Offset(dx, h * 0.5 + barH / 2), stroke);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color || oldDelegate.strokeW != strokeW;
}
