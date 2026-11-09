import 'package:flutter/material.dart';

import '../models/diagnosis.dart';
import '../widgets/disclaimer.dart';
import 'remedes_screen.dart';
import '../widgets/status_chip.dart';

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
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Résultat')),
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
                Text(info.name, style: t.headlineSmall),
                const SizedBox(height: 4),
                Text('Confiance : ${(diagnosis.confidence * 100).round()} %', style: t.bodyMedium),
                const SizedBox(height: 16),
                Text('Que faire maintenant', style: t.titleMedium),
                const SizedBox(height: 8),
                for (var i = 0; i < info.advice.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('${i + 1}. ${info.advice[i]}', style: t.bodyLarge),
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
            child: const Text('Voir les conseils et remèdes'),
          ),
          const SizedBox(height: 16),
          const Disclaimer(),
          const SizedBox(height: 8),
          Text('Version de démonstration : le résultat est factice tant que le modèle n\'est pas branché.',
              style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
