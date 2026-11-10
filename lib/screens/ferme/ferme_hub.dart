import 'package:flutter/material.dart';

import '../../services/farm_store.dart';
import '../../services/session.dart';
import '../../theme/colors.dart';
import '../../widgets/kpi_card.dart';
import 'bands_screen.dart';
import 'entry_screen.dart';
import 'finances_screen.dart';
import 'stocks_screen.dart';
import 'tasks_screen.dart';
import '../../l10n/l10n.dart';

class FermeHub extends StatelessWidget {
  const FermeHub({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: FarmStore.instance,
      builder: (context, _) {
        final s = FarmStore.instance;
        final m = s.mortality7d;
        final margin = s.monthMargin;
        return Scaffold(
          appBar: AppBar(title: const Tx('Ma ferme')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Tx(Session.instance.farmLine, style: t.bodyMedium),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  KpiCard(label: 'Volailles vivantes', value: '${s.totalAlive}', sub: trf('sur {0} placées', [s.totalPlaced])),
                  KpiCard(
                    label: 'Mortalité 7 jours',
                    value: '${m.dec1} %',
                    sub: m <= 2 ? 'Sous le seuil de 2 %' : 'Au-dessus du seuil de 2 %',
                    subColor: m <= 2 ? SifaColors.ok : SifaColors.danger,
                  ),
                  KpiCard(label: "Aliment aujourd'hui", value: '${s.feedToday.round()} kg'),
                  KpiCard(
                    label: 'Marge du mois',
                    value: '${margin >= 0 ? '+' : ''}${fcfa(margin)}',
                    sub: 'FCFA',
                    subColor: margin >= 0 ? SifaColors.ok : SifaColors.danger,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _tile(context, Icons.groups, 'Bandes', trf('{0} en cours', [s.bands.length]), const BandsScreen()),
              _tile(context, Icons.edit_note, 'Saisie du jour', trf('{0} sur {1} saisies', [s.todayEntriesCount, s.bands.length]), const EntryScreen()),
              _tile(context, Icons.inventory_2_outlined, 'Stocks', trf('{0} articles', [s.stock.length]), const StocksScreen()),
              _tile(context, Icons.show_chart, 'Finances', 'Ventes et dépenses', const FinancesScreen()),
              _tile(context, Icons.checklist, 'Tâches', trf('{0} à faire', [s.tasks.where((x) => !x.done).length]), const TasksScreen()),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String sub, Widget page) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          child: ListTile(
            leading: Icon(icon, color: SifaColors.brand),
            title: Tx(title),
            subtitle: Tx(sub),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
          ),
        ),
      );
}
