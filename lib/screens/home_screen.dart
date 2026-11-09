import 'package:flutter/material.dart';

import '../widgets/sifa_mark.dart';
import '../widgets/status_chip.dart';
import 'result_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(children: [
          const SifaMark(size: 44),
          const SizedBox(width: 12),
          Text('SIFA', style: t.headlineSmall),
        ]),
        const SizedBox(height: 24),
        Text('Bonjour', style: t.displayMedium),
        const SizedBox(height: 4),
        Text('Photographiez une fiente pour vérifier la santé de votre bande.', style: t.bodyLarge),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text('Dernière analyse', style: t.titleMedium),
            subtitle: const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(SifaStatus.warn, 'Exemple – à surveiller'),
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ResultScreen()),
            ),
          ),
        ),
      ],
    );
  }
}
