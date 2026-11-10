import 'package:flutter/material.dart';

import '../models/diagnosis.dart';
import '../widgets/disclaimer.dart';
import 'remedes_screen.dart';
import '../widgets/status_chip.dart';
import '../l10n/l10n.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.diagnosis});
  final Diagnosis diagnosis;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final info = diagnosis.info;
    final label = switch (info.status) {
      SifaStatus.ok => 'Rien à signaler',
      SifaStatus.warn => 'À surveiller',
      SifaStatus.danger => 'À traiter',
      SifaStatus.neutral => 'Information',
    };
    return Scaffold(
      appBar: AppBar(title: const Tx('Résultat')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(diagnosis.photo, height: 200, fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StatusChip(info.status, label),
                const SizedBox(height: 12),
                Tx(info.name, style: t.headlineSmall),
                const SizedBox(height: 4),
                Tx(trf('Confiance : {0} %', [(diagnosis.confidence * 100).round()]), style: t.bodyMedium),
                const SizedBox(height: 16),
                Tx('Que faire maintenant', style: t.titleMedium),
                const SizedBox(height: 8),
                for (var i = 0; i < info.advice.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Tx('${i + 1}. ${tr(info.advice[i])}', style: t.bodyLarge),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => RemedesScreen(disease: diagnosis.disease)),
            ),
            child: const Tx('Voir les conseils et remèdes'),
          ),
          const SizedBox(height: 16),
          const Disclaimer(),
          const SizedBox(height: 8),
          Tx('Version de démonstration : le résultat est factice tant que le modèle n\'est pas branché.',
              style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
