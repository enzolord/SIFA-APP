import 'package:flutter/material.dart';

import '../../services/farm_store.dart';
import '../../theme/colors.dart';
import '../../widgets/form_dialog.dart';
import '../../widgets/kpi_card.dart';

class FinancesScreen extends StatelessWidget {
  const FinancesScreen({super.key});

  Future<void> _add(BuildContext context, bool sale) async {
    final v = await showFormDialog(
      context,
      title: sale ? 'Ajouter une vente' : 'Ajouter une dépense',
      fields: [
        FieldSpec(sale ? 'Description' : 'Description', hint: sale ? 'Vente de 200 poulets' : 'Sacs de maïs'),
        const FieldSpec('Montant (FCFA)', number: true, hint: '150000'),
        if (!sale) const FieldSpec('Catégorie', hint: 'Aliment, Poussins, Santé, Autres'),
      ],
    );
    if (v == null || toNum(v[1]) <= 0) return;
    FarmStore.instance.addTxn(Txn(
      date: DateTime.now(),
      label: v[0].isEmpty ? (sale ? 'Vente' : 'Dépense') : v[0],
      amount: toNum(v[1]),
      isSale: sale,
      category: sale ? 'Vente' : (v[2].isEmpty ? 'Autres' : v[2]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: FarmStore.instance,
      builder: (context, _) {
        final s = FarmStore.instance;
        final cats = s.expensesByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final margin = s.monthMargin;
        return Scaffold(
          appBar: AppBar(title: const Text('Finances')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(children: [
                Expanded(child: KpiCard(label: 'Ventes', value: fcfa(s.monthSales), sub: 'FCFA')),
                const SizedBox(width: 12),
                Expanded(child: KpiCard(label: 'Dépenses', value: fcfa(s.monthExpenses), sub: 'FCFA')),
              ]),
              const SizedBox(height: 12),
              KpiCard(
                label: 'Marge du mois',
                value: '${margin >= 0 ? '+' : ''}${fcfa(margin)} FCFA',
                subColor: margin >= 0 ? SifaColors.ok : SifaColors.danger,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Où va l'argent", style: t.titleMedium),
                    const SizedBox(height: 12),
                    if (cats.isEmpty) Text('Aucune dépense ce mois-ci.', style: t.bodyMedium),
                    for (final c in cats) ...[
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(c.key),
                        Text(fcfa(c.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: s.monthExpenses == 0 ? 0 : c.value / s.monthExpenses,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                        backgroundColor: SifaColors.surfaceSunken,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () => _add(context, true),
                    child: const Text('+ Vente'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () => _add(context, false),
                    child: const Text('+ Dépense'),
                  ),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}
