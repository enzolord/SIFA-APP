import 'package:flutter/material.dart';

import '../data/knowledge.dart';
import '../l10n/l10n.dart';
import '../models/diagnosis.dart';
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
              MaterialPageRoute<void>(builder: (_) => RemedesScreen(disease: d.disease)),
            ),
            child: const Tx('Voir les conseils et traitements'),
          ),
          const SizedBox(height: 16),
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
