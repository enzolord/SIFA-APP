import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Profil', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 16),
        const Card(child: ListTile(leading: Icon(Icons.agriculture), title: Text('Mes élevages'), subtitle: Text('Bientôt'))),
        const SizedBox(height: 12),
        const Card(child: ListTile(leading: Icon(Icons.sync), title: Text('Synchronisation'), subtitle: Text('Bientôt'))),
        const SizedBox(height: 12),
        const Card(child: ListTile(leading: Icon(Icons.gavel), title: Text('Mentions légales'), subtitle: Text('Bientôt'))),
      ],
    );
  }
}
