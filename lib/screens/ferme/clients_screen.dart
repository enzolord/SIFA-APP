import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/analytics.dart';
import '../../services/farm_store.dart';
import '../../widgets/form_dialog.dart';

/// Carnet de clients : qui achète, combien, avec son téléphone. Les clients se créent aussi en saisissant une vente.
class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final v = await showFormDialog(context, title: 'Ajouter un client', fields: const [
      FieldSpec('Nom du client', hint: 'Mme Ngo'),
      FieldSpec('Téléphone', hint: 'Facultatif'),
    ]);
    if (v == null || v[0].isEmpty) return;
    FarmStore.instance.addClient(Client(name: v[0], phone: v[1]));
    Analytics.instance.action('ferme:client_ajout');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FarmStore.instance,
      builder: (context, _) {
        final s = FarmStore.instance;
        final list = [...s.clients]..sort((a, b) => s.totalBoughtBy(b.name).compareTo(s.totalBoughtBy(a.name)));
        return Scaffold(
          appBar: AppBar(title: const Tx('Clients')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _add(context),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Tx('Ajouter un client'),
          ),
          body: list.isEmpty
              ? const Center(child: Tx('Aucun client pour le moment.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    for (final c in list)
                      Dismissible(
                        key: ObjectKey(c),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => FarmStore.instance.removeClient(c),
                        background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
                        child: Card(
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                            title: Text(c.name),
                            subtitle: Text([
                              if (c.phone.isNotEmpty) c.phone,
                              trf('{0} achats', [s.salesTo(c.name).length]),
                            ].join(' · ')),
                            trailing: Text('${fcfa(s.totalBoughtBy(c.name))} FCFA', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
