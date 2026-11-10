import 'package:flutter/material.dart';

import '../widgets/disclaimer.dart';
import 'pharmacie_screen.dart';
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
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Card(child: ListTile(leading: Icon(Icons.menu_book), title: Tx('Fiches maladies (bientôt)'))),
        ),
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
