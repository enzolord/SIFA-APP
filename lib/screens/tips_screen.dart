import 'package:flutter/material.dart';

import '../widgets/disclaimer.dart';
import '../models/diagnosis.dart';
import 'pharmacie_screen.dart';
import 'remedes_screen.dart';
import 'prophylaxie_screen.dart';
import '../l10n/l10n.dart';

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Tx('Conseils')),
      body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _tile(context, 'Calendrier de vaccination', Icons.vaccines, const ProphylaxieScreen()),
        _tile(context, 'Pharmacies vétérinaires', Icons.local_pharmacy, const PharmacieScreen()),
        _tile(context, 'Fiches maladies', Icons.menu_book, const DiseaseSheetsScreen()),
        const SizedBox(height: 8),
        const Disclaimer(),
      ],
    ));
  }

  Widget _tile(BuildContext context, String title, IconData icon, Widget page) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          child: ListTile(
            leading: Icon(icon),
            title: Tx(title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
          ),
        ),
      );
}

/// Liste des fiches maladies (reconnaître, traiter, prévenir).
class DiseaseSheetsScreen extends StatelessWidget {
  const DiseaseSheetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const order = [Disease.coccidiosis, Disease.salmonella, Disease.newcastle, Disease.healthy];
    return Scaffold(
      appBar: AppBar(title: const Tx('Fiches maladies')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final d in order)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  leading: Icon(d == Disease.healthy ? Icons.check_circle_outline : Icons.coronavirus_outlined),
                  title: Tx(diseaseInfo[d]!.shortName),
                  subtitle: const Tx('Reconnaître, traiter, prévenir'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => RemedesScreen(disease: d)),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Disclaimer(),
        ],
      ),
    );
  }
}
