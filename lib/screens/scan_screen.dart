import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/analysis_store.dart';
import '../services/analytics.dart';
import '../services/classifier.dart';
import '../services/dropping_check.dart';
import '../services/entitlement.dart';
import '../services/remote_content.dart';
import 'abonnement_screen.dart';
import '../theme/colors.dart';
import 'signs_screen.dart';
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
    if (!Entitlement.instance.canAnalyze) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final f = await _picker.pickImage(source: source, maxWidth: 1280, imageQuality: 90);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      // Gemini (en ligne) et le modèle embarqué travaillent en même temps ; sans réseau ou si
      // Gemini tarde, le modèle embarqué décide seul.
      final online = DroppingCheck.verify(bytes);
      final outcome = await AnalysisStore.instance.classifier.analyze(bytes);
      final gem = await online.timeout(const Duration(seconds: 4), onTimeout: () => DroppingCheckResult.unknown);
      if (!mounted) return;
      final probs = outcome.probs;
      final rejectedByGemini = probs != null && gem.verdict == DroppingVerdict.notDropping;
      Analytics.instance.track('scan', {
        'issue': rejectedByGemini ? 'notDropping' : (outcome.issue?.name ?? 'ok'),
        'gemini': gem.verdict.name,
      });
      if (rejectedByGemini) {
        final seen = L10n.en ? gem.seenEn : gem.seenFr;
        setState(() => _message = seen.isEmpty
            ? tr('Cette photo ne montre pas une fiente, ou elle est trop floue. SIFA analyse uniquement les fientes de poule.')
            : trf('Cette photo montre : {0}. SIFA analyse uniquement les fientes de poule.', [seen]));
        return;
      }
      if (probs == null) {
        setState(() => _message = switch (outcome.issue) {
              ScanIssue.tooDark => 'Photo trop sombre. Reprenez-la à la lumière du jour.',
              ScanIssue.tooPlain =>
                'Je ne vois pas de fiente sur cette photo. Cadrez une fiente fraîche, de près.',
              ScanIssue.notDropping =>
                'Cette photo ne montre pas une fiente, ou elle est trop floue. SIFA analyse uniquement les fientes de poule.',
              ScanIssue.modelError => "L'analyse n'a pas pu démarrer. Fermez l'application et réessayez.",
              _ => 'Photo peu claire. Rapprochez-vous et reprenez-la en pleine lumière.',
            });
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(settings: const RouteSettings(name: 'SignsScreen'), builder: (_) => SignsScreen(photo: bytes, photoProbs: probs)),
      );
    } catch (_) {
      if (mounted) setState(() => _message = "Impossible d'ouvrir la photo. Réessayez.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _quotaLogged = false;

  Widget _blocked(TextTheme t) {
    final e = Entitlement.instance;
    if (!_quotaLogged) {
      _quotaLogged = true;
      Analytics.instance.track('quota_atteint', {'offre': e.offerId ?? 'gratuit', 'limite': e.limit});
    }
    return Container(
      color: SifaColors.ink,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.lock_outline_rounded, size: 56, color: SifaColors.yolk),
        const SizedBox(height: 18),
        Tx(e.isFree ? 'Vos analyses gratuites sont terminées' : 'Vous avez utilisé toutes les analyses de votre formule',
            textAlign: TextAlign.center, style: t.titleLarge?.copyWith(color: Colors.white)),
        const SizedBox(height: 10),
        Text(
          e.isFree
              ? trf('Vous avez fait vos {0} analyses offertes. Choisissez une formule pour continuer à analyser les fientes de vos poulets.', [e.limit ?? 0])
              : tr('Votre quota se renouvelle tous les 30 jours. Vous pouvez aussi passer à une formule plus grande.'),
          textAlign: TextAlign.center,
          style: t.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: SifaColors.yolk, foregroundColor: SifaColors.onYolk, minimumSize: const Size(220, 52)),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(settings: const RouteSettings(name: 'AbonnementScreen'), builder: (_) => const AbonnementScreen())),
          icon: const Icon(Icons.workspace_premium_rounded),
          label: const Tx('Voir les formules'),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Entitlement.instance, RemoteContent.instance]),
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        if (!Entitlement.instance.canAnalyze) return _blocked(t);
        _quotaLogged = false;
        return _scanner(context, t);
      },
    );
  }

  Widget _scanner(BuildContext context, TextTheme t) {
    final e = Entitlement.instance;
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
        const SizedBox(height: 4),
        Tx('Une seule fiente fraîche, qui remplit le cadre',
            style: t.bodyMedium?.copyWith(color: Colors.white70)),
        if (e.remaining != null && e.remaining! <= (e.isFree ? 5 : 10)) ...[
          const SizedBox(height: 10),
          Text(
            e.isFree
                ? trf('Analyses gratuites restantes : {0} sur {1}', [e.remaining!, e.limit!])
                : trf('Analyses restantes ce mois : {0} sur {1}', [e.remaining!, e.limit!]),
            style: t.bodyMedium?.copyWith(color: SifaColors.yolk, fontWeight: FontWeight.w600),
          ),
        ],
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
