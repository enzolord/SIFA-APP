import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Symbole SIFA : fiente vue dans un cadre de scan, traversée par une ligne de rythme cardiaque.
class SifaMark extends StatelessWidget {
  const SifaMark({super.key, this.size = 96, this.onDark = false});
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _MarkPainter(onDark));
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.onDark);
  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 96;
    canvas.scale(k);
    final frame = onDark ? Colors.white : SifaColors.ink;
    final body = onDark ? const Color(0xFFC98F55) : SifaColors.dropping;
    final cap = onDark ? Colors.white : const Color(0xFFFFF6E3);

    final ecg = Path()
      ..moveTo(6, 56)..lineTo(33, 56)..lineTo(39, 56)..lineTo(44, 46)
      ..lineTo(51, 66)..lineTo(56, 56)..lineTo(90, 56);

    canvas.saveLayer(const Rect.fromLTWH(0, 0, 96, 96), Paint());
    canvas.save();
    canvas.translate(48, 56);
    canvas.scale(0.92);
    canvas.translate(-48, -56 - 12 / 0.92);
    final mound = Path()
      ..moveTo(15, 76)
      ..cubicTo(11, 66, 21, 60, 25, 53)
      ..cubicTo(26, 43, 36, 37, 44, 39)
      ..cubicTo(48, 29, 63, 29, 67, 39)
      ..cubicTo(77, 40, 83, 51, 80, 60)
      ..cubicTo(87, 66, 85, 77, 74, 79)
      ..cubicTo(60, 83, 33, 83, 21, 80)
      ..cubicTo(17, 79, 15, 78, 15, 76)
      ..close();
    canvas.drawPath(mound, Paint()..color = body);
    final urate = Path()
      ..moveTo(36, 47)
      ..cubicTo(35, 40, 45, 37, 51, 41)
      ..cubicTo(57, 45, 55, 53, 48, 54)
      ..cubicTo(41, 55, 37, 52, 36, 47)
      ..close();
    canvas.drawPath(urate, Paint()..color = cap);
    canvas.restore();
    // découpe autour de la ligne
    canvas.drawPath(
      ecg,
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    canvas.drawPath(
      ecg,
      Paint()
        ..color = SifaColors.yolk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final f = Paint()
      ..color = frame
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final p in [
      [10.0, 25.0, 10.0, 10.0, 25.0, 10.0],
      [71.0, 10.0, 86.0, 10.0, 86.0, 25.0],
      [86.0, 71.0, 86.0, 86.0, 71.0, 86.0],
      [25.0, 86.0, 10.0, 86.0, 10.0, 71.0],
    ]) {
      canvas.drawPath(
        Path()..moveTo(p[0], p[1])..lineTo(p[2], p[3])..lineTo(p[4], p[5]),
        f,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.onDark != onDark;
}
