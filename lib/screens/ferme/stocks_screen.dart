import 'package:flutter/material.dart';

import '../../services/farm_store.dart';
import '../../theme/colors.dart';
import '../../widgets/form_dialog.dart';
import '../../widgets/status_chip.dart';
import '../../l10n/l10n.dart';

class StocksScreen extends StatelessWidget {
  const StocksScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final v = await showFormDialog(context, title: 'Ajouter un article', fields: const [
      FieldSpec('Nom', hint: 'Aliment croissance'),
      FieldSpec('Quantité', number: true, hint: '500'),
      FieldSpec('Unité', hint: 'kg'),
      FieldSpec('Consommation par jour (facultatif)', number: true, hint: '40'),
    ]);
    if (v == null || v[0].isEmpty) return;
    FarmStore.instance.addStock(StockItem(
      name: v[0],
      qty: toNum(v[1]),
      unit: v[2].isEmpty ? 'unités' : v[2],
      dailyUse: toNum(v[3]),
    ));
  }

  Future<void> _move(BuildContext context, StockItem s) async {
    final v = await showFormDialog(context, title: s.name, confirm: 'Appliquer', fields: const [
      FieldSpec('Variation (+ entrée, − sortie)', number: true, hint: '-50'),
    ]);
    if (v == null) return;
    FarmStore.instance.adjustStock(s, toNum(v[0]));
  }

  (SifaStatus, String) _status(StockItem s) {
    final d = s.daysLeft;
    if (s.qty <= 0) return (SifaStatus.danger, 'Épuisé');
    if (d == null) return (SifaStatus.neutral, 'En stock');
    if (d <= 3) return (SifaStatus.danger, 'Bientôt épuisé');
    if (d <= 7) return (SifaStatus.warn, 'À commander');
    return (SifaStatus.ok, 'Suffisant');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: FarmStore.instance,
      builder: (context, _) {
        final items = FarmStore.instance.stock;
        return Scaffold(
          appBar: AppBar(title: const Tx('Stocks')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Tx('Ajouter un article'),
          ),
          body: items.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Tx('Aucun article. Ajoutez votre aliment, vos vaccins et médicaments.', textAlign: TextAlign.center)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                  children: [
                    for (final s in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _move(context, s),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Tx(s.name, style: t.titleMedium)),
                                  StatusChip(_status(s).$1, _status(s).$2),
                                ]),
                                const SizedBox(height: 6),
                                Tx(
                                  '${s.qty.round()} ${tr(s.unit)}${s.daysLeft != null ? trf(' · environ {0} jours', [s.daysLeft!]) : ''}',
                                  style: t.bodyMedium?.copyWith(color: SifaColors.inkMuted),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    Tx('Touchez un article pour ajouter ou retirer une quantité.', style: t.bodyMedium),
                  ],
                ),
        );
      },
    );
  }
}
