import 'package:flutter/material.dart';

import '../widgets/disclaimer.dart';
import '../widgets/status_chip.dart';

/// Écran de résultat – données d'exemple tant que le modèle n'est pas branché.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Résultat')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const StatusChip(SifaStatus.warn, 'À surveiller'),
                const SizedBox(height: 12),
                Text('Maladie probable (exemple)', style: t.headlineSmall),
                const SizedBox(height: 4),
                Text('Confiance : 87 %', style: t.bodyMedium),
                const SizedBox(height: 16),
                Text('Que faire maintenant', style: t.titleMedium),
                const SizedBox(height: 8),
                const Text('1. Isoler les sujets qui semblent atteints.'),
                const Text("2. Vérifier l'eau et l'hygiène du bâtiment."),
                const Text('3. Contacter votre vétérinaire si cela persiste.'),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Disclaimer(),
        ],
      ),
    );
  }
}
