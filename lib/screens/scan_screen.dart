import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Placeholder : la caméra et le modèle TFLite arrivent au Sprint 1.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      color: SifaColors.ink,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 240,
          height: 240,
          child: CustomPaint(painter: _FramePainter()),
        ),
        const SizedBox(height: 24),
        Text('Placez la fiente dans le cadre',
            style: t.titleMedium?.copyWith(color: Colors.white)),
        const SizedBox(height: 8),
        Text('Caméra et analyse : prochain sprint',
            style: t.bodyMedium?.copyWith(color: Colors.white70)),
      ]),
    );
  }
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = SifaColors.yolk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    const l = 48.0;
    final w = s.width, h = s.height;
    for (final c in [
      [0.0, 0.0, 1.0, 1.0],
      [w, 0.0, -1.0, 1.0],
      [w, h, -1.0, -1.0],
      [0.0, h, 1.0, -1.0],
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(c[0] + c[2] * l, c[1])
          ..lineTo(c[0], c[1])
          ..lineTo(c[0], c[1] + c[3] * l),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
