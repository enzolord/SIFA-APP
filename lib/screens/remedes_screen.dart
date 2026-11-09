import 'package:flutter/material.dart';

import '../models/diagnosis.dart';
import '../theme/colors.dart';

class RemedesScreen extends StatelessWidget {
  const RemedesScreen({super.key, required this.disease});
  final Disease disease;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final info = diseaseInfo[disease]!;
    return Scaffold(
      appBar: AppBar(title: const Text('Conseils et remèdes')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(info.name, style: t.displayMedium),
          const SizedBox(height: 16),
          _block(t, 'À faire maintenant', info.advice.join('\n• ').replaceFirst('', '• ')),
          const SizedBox(height: 12),
          _block(t, 'Traitement',
              'Le traitement est choisi avec votre vétérinaire. Il vous indique le produit et la dose adaptés à votre élevage.'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: SifaColors.dangerSoft, borderRadius: BorderRadius.circular(12)),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.warning_rounded, color: SifaColors.danger),
              SizedBox(width: 10),
              Expanded(child: Text("N'utilisez pas de médicament sans l'avis d'un vétérinaire.")),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _block(TextTheme t, String title, String body) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleMedium),
            const SizedBox(height: 8),
            Text(body, style: t.bodyLarge),
          ]),
        ),
      );
}
