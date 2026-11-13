import 'package:flutter/material.dart';

import 'abonnement_screen.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
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
        const _AccountCard(),
        const SizedBox(height: 12),
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

/// Photo, nom et e-mail du compte connecté (Google), avec la ligne d'élevage.
class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: Listenable.merge([AuthService.instance, Session.instance]),
      builder: (context, _) {
        final auth = AuthService.instance;
        final name = auth.displayName;
        final initial = (name.isNotEmpty ? name : auth.email).trim();
        final photo = auth.photoUrl;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(
                radius: 32,
                backgroundImage: photo == null ? null : NetworkImage(photo),
                onBackgroundImageError: photo == null ? null : (_, __) {},
                child: photo == null
                    ? (initial.isEmpty
                        ? const Icon(Icons.person_rounded, size: 32)
                        : Text(initial[0].toUpperCase(), style: t.headlineSmall))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (name.isNotEmpty) Text(name, style: t.titleMedium),
                  if (auth.signedIn)
                    Text(auth.email, style: t.bodyMedium)
                  else
                    const Tx('Non connecté'),
                  if (Session.instance.onboarded) Text(Session.instance.farmLine, style: t.bodySmall),
                  if (auth.signedIn)
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                      onPressed: auth.signOut,
                      child: const Tx('Se déconnecter'),
                    ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}
