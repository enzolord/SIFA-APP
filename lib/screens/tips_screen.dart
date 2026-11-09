import 'package:flutter/material.dart';

import '../widgets/disclaimer.dart';

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  static const _items = [
    'Fiches maladies (bientôt)',
    'Bien photographier une fiente (bientôt)',
    'Quand appeler le vétérinaire (bientôt)',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Conseils', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 16),
        for (final i in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(child: ListTile(title: Text(i), trailing: const Icon(Icons.chevron_right))),
          ),
        const SizedBox(height: 8),
        const Disclaimer(),
      ],
    );
  }
}
