import 'package:flutter/material.dart';

import 'abonnement_screen.dart';
import '../l10n/l10n.dart';
import '../widgets/language_switch.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Tx('Profil', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.language_rounded),
                SizedBox(width: 12),
                Tx('Langue / Language'),
              ]),
              SizedBox(height: 12),
              LanguageSwitch(),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        const Card(child: ListTile(leading: Icon(Icons.agriculture), title: Tx('Mes élevages'), subtitle: Tx('Bientôt'))),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.workspace_premium),
            title: const Tx('Formules'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AbonnementScreen()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(child: ListTile(leading: Icon(Icons.sync), title: Tx('Synchronisation'), subtitle: Tx('Bientôt'))),
        const SizedBox(height: 12),
        const Card(child: ListTile(leading: Icon(Icons.gavel), title: Tx('Mentions légales'), subtitle: Tx('Bientôt'))),
      ],
    );
  }
}
