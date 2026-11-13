import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/farm_store.dart';
import '../../services/session.dart';
import '../../theme/colors.dart';
import '../../widgets/kpi_card.dart';

/// Résultats par bande : mortalité, aliment, indice de consommation (poulets de chair), taux de ponte (pondeuses).
class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: FarmStore.instance,
      builder: (context, _) {
        final s = FarmStore.instance;
        return Scaffold(
          appBar: AppBar(title: const Tx('Performances')),
          body: s.bands.isEmpty
              ? const Center(child: Tx("Ajoutez d'abord une bande."))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final b in s.bands) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Text(trf('{0} · jour {1} · {2}', [b.name, b.day, tr(b.type.label)]), style: t.titleMedium),
                      ),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.7,
                        children: [
                          KpiCard(
                            label: 'Mortalité cumulée',
                            value: '${s.mortalityPct(b).dec1} %',
                            sub: trf('{0} sur {1}', [s.deadTotal(b), b.initialCount]),
                            subColor: s.mortalityPct(b) > 2 ? SifaColors.danger : SifaColors.ok,
                          ),
                          KpiCard(label: 'Aliment par oiseau', value: s.feedPerBirdG(b) == null ? '—' : '${s.feedPerBirdG(b)!.round()} g', sub: 'par jour'),
                          if (b.type == FlockType.layer) ...[
                            KpiCard(label: 'Taux de ponte (7 jours)', value: s.layingRate(b) == null ? '—' : '${s.layingRate(b)!.round()} %'),
                            KpiCard(label: 'Œufs aujourd\'hui', value: '${s.eggsToday(b)}'),
                          ] else ...[
                            KpiCard(label: 'Poids moyen', value: s.lastWeight(b) == null ? '—' : '${s.lastWeight(b)!.round()} g'),
                            KpiCard(label: 'Indice de consommation', value: s.feedConversion(b) == null ? '—' : s.feedConversion(b)!.toStringAsFixed(2), sub: 'plus bas = mieux'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                    Tx("Ces chiffres sont calculés avec ce que vous saisissez chaque jour. Comparez-les aux objectifs de la souche que vous élevez (fiche du fournisseur de poussins) ou demandez conseil à un technicien.", style: t.bodySmall),
                  ],
                ),
        );
      },
    );
  }
}
