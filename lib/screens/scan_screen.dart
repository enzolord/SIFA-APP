import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/analysis_store.dart';
import '../theme/colors.dart';
import 'result_screen.dart';
import '../l10n/l10n.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  bool _busy = false;
  String? _message;

  Future<void> _go(ImageSource source) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final f = await _picker.pickImage(source: source, maxWidth: 1280, imageQuality: 90);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      final store = AnalysisStore.instance;
      final d = await store.classifier.classify(bytes);
      if (!mounted) return;
      if (d == null) {
        setState(() => _message = 'Photo peu claire. Rapprochez-vous et reprenez-la en pleine lumière.');
        return;
      }
      store.add(d);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ResultScreen(diagnosis: d)),
      );
    } catch (_) {
      if (mounted) setState(() => _message = "Impossible d'ouvrir la photo. Réessayez.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      color: SifaColors.ink,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 240, height: 240, child: CustomPaint(painter: _FramePainter())),
        const SizedBox(height: 24),
        Tx('Placez la fiente dans le cadre',
            style: t.titleMedium?.copyWith(color: Colors.white)),
        const SizedBox(height: 8),
        Tx('Lumière du jour, 20 à 30 cm, photo nette',
            style: t.bodyMedium?.copyWith(color: Colors.white70)),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Tx(_message!, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: SifaColors.yolk)),
        ],
        const SizedBox(height: 24),
        if (_busy)
          const CircularProgressIndicator(color: SifaColors.yolk)
        else ...[
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: SifaColors.yolk,
              foregroundColor: SifaColors.onYolk,
              minimumSize: const Size(220, 52),
            ),
            onPressed: () => _go(ImageSource.camera),
            icon: const Icon(Icons.photo_camera),
            label: const Tx('Prendre la photo'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _go(ImageSource.gallery),
            child: const Tx('Choisir dans la galerie', style: TextStyle(color: Colors.white)),
          ),
        ],
      ]),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter();

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
