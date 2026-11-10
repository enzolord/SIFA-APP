import 'package:flutter/material.dart';

import '../../services/farm_store.dart';
import '../../services/session.dart';
import '../../theme/colors.dart';
import '../../widgets/kpi_card.dart';
import 'entry_screen.dart';
import '../../l10n/l10n.dart';

class BandDetailScreen extends StatelessWidget {
  const BandDetailScreen({super.key, required this.band});
  final Band band;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: FarmStore.instance,
      builder: (context, _) {
        final s = FarmStore.instance;
        final weights = s.entriesOf(band).where((e) => e.avgWeightG != null).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        final shown = weights.length > 8 ? weights.sublist(weights.length - 8) : weights;
        final maxW = shown.fold<double>(1, (m, e) => e.avgWeightG! > m ? e.avgWeightG! : m);
        return Scaffold(
          appBar: AppBar(title: Tx(band.name)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  KpiCard(label: 'Jour', value: '${band.day}', sub: band.type.label),
                  KpiCard(label: 'Oiseaux vivants', value: '${s.alive(band)}', sub: trf('sur {0}', [band.initialCount])),
                  KpiCard(
                    label: 'Mortalité cumulée',
                    value: '${s.mortalityPct(band).dec1} %',
                    sub: trf('{0} oiseaux', [s.deadTotal(band)]),
                    subColor: s.mortalityPct(band) > 2 ? SifaColors.danger : SifaColors.ok,
                  ),
                  KpiCard(label: 'Aliment consommé', value: '${s.feedTotal(band).round()} kg'),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Tx('Poids moyen (g)', style: t.titleMedium),
                    const SizedBox(height: 12),
                    if (shown.isEmpty)
                      Tx('Saisissez un poids dans la saisie du jour pour voir la courbe.', style: t.bodyMedium)
                    else
                      SizedBox(
                        height: 150,
                        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          for (final e in shown)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                  Tx('${e.avgWeightG!.round()}', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 100 * e.avgWeightG! / maxW,
                                    decoration: const BoxDecoration(
                                      color: SifaColors.brand,
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                        ]),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => EntryScreen(initialBand: band)),
                ),
                child: const Tx('Saisir la journée'),
              ),
            ],
          ),
        );
      },
    );
  }
}
