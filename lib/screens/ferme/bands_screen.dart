import 'package:flutter/material.dart';

import '../../services/farm_store.dart';
import '../../services/session.dart';
import '../../theme/colors.dart';
import '../../widgets/form_dialog.dart';
import 'band_detail_screen.dart';
import '../../l10n/l10n.dart';

class BandsScreen extends StatelessWidget {
  const BandsScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final v = await showFormDialog(context, title: 'Ajouter une bande', fields: const [
      FieldSpec('Nom de la bande', hint: 'Bande B'),
      FieldSpec('Nombre de volailles', number: true, hint: '500'),
      FieldSpec('Prix des poussins (FCFA)', number: true, hint: 'Facultatif'),
    ]);
    if (v == null || v[0].isEmpty || toNum(v[1]) <= 0) return;
    FarmStore.instance.addBand(v[0], Session.instance.flockType, toNum(v[1]).round(), chickCost: toNum(v[2]));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: FarmStore.instance,
      builder: (context, _) {
        final s = FarmStore.instance;
        return Scaffold(
          appBar: AppBar(title: const Tx('Mes bandes')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Tx('Ajouter une bande'),
          ),
          body: s.bands.isEmpty
              ? const Center(child: Tx('Aucune bande pour le moment.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                  children: [
                    for (final b in s.bands)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(settings: const RouteSettings(name: 'BandDetailScreen'), builder: (_) => BandDetailScreen(band: b)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Tx(b.name, style: t.titleMedium),
                                const SizedBox(height: 2),
                                Tx(trf('{0} · jour {1} · {2} poulets', [tr(b.type.label), b.day, s.alive(b)]), style: t.bodyMedium),
                                const SizedBox(height: 10),
                                Tx(
                                  trf('Mortalité {0} %', [s.mortalityPct(b).dec1]),
                                  style: t.bodyMedium?.copyWith(
                                    color: s.mortalityPct(b) > 2 ? SifaColors.danger : SifaColors.ok,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ]),
                            ),
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
