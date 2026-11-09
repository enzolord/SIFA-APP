import 'package:flutter/material.dart';

import '../widgets/status_chip.dart';

class PharmacieScreen extends StatelessWidget {
  const PharmacieScreen({super.key});

  // Données d'exemple : le vrai annuaire viendra de Supabase (table pharmacies).
  static const _items = [
    ('Pharmacie vétérinaire du Centre', "2,4 km · ouverte jusqu'à 18:00", SifaStatus.ok, 'En stock'),
    ('Agro-Vet Bonabéri', "5,8 km · ouverte jusqu'à 17:30", SifaStatus.warn, 'Stock limité'),
    ('Élevage Plus Logbessou', '9,1 km · fermée, ouvre à 08:00', SifaStatus.danger, 'Rupture'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pharmacies vétérinaires')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final (name, detail, status, label) in _items) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: t.titleMedium),
                  const SizedBox(height: 4),
                  Text(detail, style: t.bodyMedium),
                  const SizedBox(height: 10),
                  StatusChip(status, label),
                ]),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text('Données d\'exemple. L\'annuaire réel arrive avec la synchronisation.',
              style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
