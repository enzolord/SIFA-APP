import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/farm_store.dart';
import '../../theme/colors.dart';

/// Rentabilité par bande : ventes - dépenses rattachées à la bande (poussins, aliment, santé...).
class ProfitScreen extends StatelessWidget {
  const ProfitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: FarmStore.instance,
      builder: (context, _) {
        final s = FarmStore.instance;
        Widget line(String label, double v, {bool bold = false, bool color = false}) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Tx(label),
                Text('${v >= 0 && color ? '+' : ''}${fcfa(v)} FCFA',
                    style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color ? (v >= 0 ? SifaColors.ok : SifaColors.danger) : null)),
              ]),
            );
        return Scaffold(
          appBar: AppBar(title: const Tx('Rentabilité par bande')),
          body: s.bands.isEmpty
              ? const Center(child: Tx("Ajoutez d'abord une bande."))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final b in s.bands)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(b.name, style: t.titleMedium),
                            const SizedBox(height: 8),
                            line('Ventes', s.salesOf(b)),
                            line('Dépenses', s.expensesOf(b)),
                            const Divider(),
                            line('Marge', s.profitOf(b), bold: true, color: true),
                            if (s.profitPerBird(b) != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(trf('Soit {0} FCFA par oiseau vivant', [fcfa(s.profitPerBird(b)!)]), style: t.bodySmall),
                              ),
                          ]),
                        ),
                      ),
                    if (s.unassignedSales > 0 || s.unassignedExpenses > 0)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Tx('Non rattaché à une bande', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            line('Ventes', s.unassignedSales),
                            line('Dépenses', s.unassignedExpenses),
                          ]),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Tx("Choisissez la bande quand vous ajoutez une vente ou une dépense, et indiquez le prix des poussins à la création de la bande : la marge de chaque bande se calcule alors toute seule.", style: t.bodySmall),
                  ],
                ),
        );
      },
    );
  }
}
