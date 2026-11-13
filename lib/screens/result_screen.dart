import 'package:flutter/material.dart';

import '../data/knowledge.dart';
import '../l10n/l10n.dart';
import '../models/diagnosis.dart';
import '../services/analysis_store.dart';
import '../services/analytics.dart';
import '../services/sample_uploader.dart';
import '../services/triage.dart';
import '../theme/colors.dart';
import '../widgets/disclaimer.dart';
import '../widgets/status_chip.dart';
import 'remedes_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.diagnosis});
  final Diagnosis diagnosis;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = diagnosis;
    final info = d.info;
    final sheet = sheetFor(d.disease);
    final probs = d.photoProbs;
    final triage = probs == null ? null : Triage.combine(probs, d.signs);
    final redFlag = triage?.redFlag ?? false;

    final statusLabel = switch (info.status) {
      SifaStatus.ok => 'Rien à signaler',
      SifaStatus.warn => 'À surveiller',
      SifaStatus.danger => 'À traiter',
      SifaStatus.neutral => 'Information',
    };
    final (relLabel, relText) = switch (d.reliability) {
      Reliability.high => ('Fiabilité : forte', 'La photo et les signes cochés vont dans le même sens.'),
      Reliability.medium => (
          'Fiabilité : moyenne',
          'Résultat à confirmer : surveillez la bande et demandez un avis si les signes continuent.'
        ),
      Reliability.low => (
          'Fiabilité : faible',
          "Résultat incertain. Refaites une photo d'une fiente fraîche et cochez les signes observés, ou demandez l'avis d'un vétérinaire."
        ),
    };

    return Scaffold(
      appBar: AppBar(title: const Tx('Résultat')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(d.photo, height: 200, fit: BoxFit.cover),
          ),
          if (redFlag) ...[
            const SizedBox(height: 16),
            _banner(
              t,
              SifaColors.dangerSoft,
              SifaColors.danger,
              Icons.warning_rounded,
              'Alerte : maladie contagieuse grave possible',
              'Une mortalité brutale ou des signes nerveux peuvent venir de la maladie de Newcastle ou de la grippe aviaire. Isolez la bande, ne vendez et ne déplacez aucun poulet, et appelez tout de suite votre vétérinaire ou les services vétérinaires.',
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StatusChip(info.status, statusLabel),
                const SizedBox(height: 12),
                Tx(info.name, style: t.headlineSmall),
                const SizedBox(height: 10),
                Tx(relLabel, style: t.titleSmall),
                const SizedBox(height: 4),
                Tx(relText, style: t.bodyMedium),
              ]),
            ),
          ),
          if (probs != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Tx('Ce que montre la photo', style: t.titleMedium),
                  const SizedBox(height: 12),
                  for (final dis in Disease.values) _bar(t, diseaseInfo[dis]!.shortName, probs[dis.index]),
                  const Divider(height: 28),
                  Tx('Ce que disent les signes', style: t.titleMedium),
                  const SizedBox(height: 8),
                  Text(_signsText(triage!), style: t.bodyMedium),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Tx('Que faire maintenant', style: t.titleMedium),
                const SizedBox(height: 8),
                for (var i = 0; i < sheet.now.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('${i + 1}. ${tr(sheet.now[i])}', style: t.bodyLarge),
                  ),
                const Divider(height: 28),
                Tx('À ne pas confondre avec', style: t.titleMedium),
                const SizedBox(height: 8),
                for (final c in sheet.confusions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${tr(c)}', style: t.bodyMedium),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(settings: const RouteSettings(name: 'RemedesScreen'), builder: (_) => RemedesScreen(disease: d.disease)),
            ),
            child: const Tx('Voir les conseils et traitements'),
          ),
          const SizedBox(height: 16),
          if (Analytics.instance.enabled) ...[
            const SizedBox(height: 16),
            _FeedbackCard(diagnosis: d),
            const SizedBox(height: 12),
            _ShareCard(diagnosis: d),
          ],
          const SizedBox(height: 8),
          const Disclaimer(),
          const SizedBox(height: 8),
          Tx(
            "L'analyse de la photo peut se tromper, surtout si l'image ne montre pas une fiente fraîche et nette. Seul un vétérinaire ou un laboratoire peut confirmer une maladie.",
            style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  String _signsText(TriageResult r) {
    if (diagnosis.signs.isEmpty) {
      return tr('Aucun signe renseigné : le résultat repose sur la photo seule.');
    }
    return switch (r.signsAgree) {
      true => tr('Les signes cochés vont dans le même sens que la photo.'),
      false => tr("Les signes cochés ne correspondent pas à la photo. Le résultat tient compte des deux, mais il reste incertain."),
      null => tr("Seuls l'âge ou la vaccination sont renseignés : cochez aussi les signes observés pour un résultat plus sûr."),
    };
  }

  Widget _bar(TextTheme t, String label, double p) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Tx(label, style: t.bodyMedium)),
            Text('${(p * 100).round()} %', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p.clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: SifaColors.surfaceSunken,
              color: SifaColors.brand,
            ),
          ),
        ]),
      );

  Widget _banner(TextTheme t, Color bg, Color fg, IconData icon, String title, String body) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Tx(title, style: t.titleSmall?.copyWith(color: fg)),
              const SizedBox(height: 4),
              Tx(body, style: t.bodyMedium?.copyWith(color: SifaColors.ink)),
            ]),
          ),
        ]),
      );
}

/// « Ce résultat était-il juste ? » : l'avis de l'éleveur alimente le taux de bonnes réponses
/// du tableau de bord. Une seule réponse par analyse tant que l'application reste ouverte.
class _FeedbackCard extends StatefulWidget {
  const _FeedbackCard({required this.diagnosis});
  final Diagnosis diagnosis;

  static final _given = <String>{};

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  bool _asking = false;

  String get _ref => AnalysisStore.refOf(widget.diagnosis);
  bool get _done => _FeedbackCard._given.contains(_ref);

  void _send(bool right, [String? real]) {
    Analytics.instance.track('retour', {'ref': _ref, 'juste': right, if (real != null) 'reelle': real});
    _FeedbackCard._given.add(_ref);
    setState(() => _asking = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (_done) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.favorite_rounded, color: SifaColors.brand),
            const SizedBox(width: 12),
            Expanded(child: Tx('Merci ! Votre avis aide à améliorer SIFA.', style: t.bodyMedium)),
          ]),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Tx('Ce résultat vous semble-t-il juste ?', style: t.titleSmall),
          const SizedBox(height: 4),
          Tx('Répondez quand vous savez, par exemple après l\'avis du vétérinaire.', style: t.bodySmall),
          const SizedBox(height: 12),
          if (!_asking)
            Row(children: [
              Expanded(child: FilledButton.tonal(onPressed: () => _send(true), child: const Tx('Oui, juste'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(onPressed: () => setState(() => _asking = true), child: const Tx('Non, faux'))),
            ])
          else ...[
            Tx('Qu\'était-ce en réalité ?', style: t.bodyMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in const {
                'healthy': 'Fiente saine',
                'coccidiosis': 'Coccidiose',
                'salmonella': 'Salmonellose',
                'newcastle': 'Maladie de Newcastle',
                'autre': 'Autre maladie',
                'inconnue': 'Je ne sais pas',
              }.entries.where((e) => e.key != widget.diagnosis.disease.name))
                ActionChip(label: Tx(e.value), onPressed: () => _send(false, e.key)),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Bouton pour partager la photo de cette analyse (si le partage automatique est désactivé).
class _ShareCard extends StatefulWidget {
  const _ShareCard({required this.diagnosis});
  final Diagnosis diagnosis;

  @override
  State<_ShareCard> createState() => _ShareCardState();
}

class _ShareCardState extends State<_ShareCard> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _share() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await SampleUploader.instance.share(widget.diagnosis);
    if (mounted) {
      setState(() {
        _busy = false;
        _failed = !ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: SampleUploader.instance,
      builder: (context, _) {
        final done = SampleUploader.instance.wasShared(widget.diagnosis);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: done
                ? Row(children: [
                    const Icon(Icons.check_circle_rounded, color: SifaColors.brand),
                    const SizedBox(width: 12),
                    Expanded(child: Tx('Photo envoyée, merci !', style: t.bodyMedium)),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Tx('Aider SIFA à progresser', style: t.titleSmall),
                    const SizedBox(height: 4),
                    Tx("Envoyez cette photo, sans votre nom. Un vétérinaire la vérifiera avant de s'en servir.", style: t.bodySmall),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _share,
                      icon: _busy
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_rounded),
                      label: const Tx('Partager cette photo'),
                    ),
                    if (_failed) ...[
                      const SizedBox(height: 8),
                      Tx("Envoi impossible. Vérifiez votre connexion et réessayez.", style: t.bodySmall),
                    ],
                  ]),
          ),
        );
      },
    );
  }
}
