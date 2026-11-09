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
          appBar: AppBar(title: const Text('Ma ferme')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(Session.instance.farmLine, style: t.bodyMedium),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  KpiCard(label: 'Volailles vivantes', value: '${s.totalAlive}', sub: 'sur ${s.totalPlaced} placées'),
                  KpiCard(
                    label: 'Mortalité 7 jours',
                    value: '${m.toStringAsFixed(1).replaceAll('.', ',')} %',
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
              _tile(context, Icons.groups, 'Bandes', '${s.bands.length} en cours', const BandsScreen()),
              _tile(context, Icons.edit_note, 'Saisie du jour', '${s.todayEntriesCount} sur ${s.bands.length} saisies', const EntryScreen()),
              _tile(context, Icons.inventory_2_outlined, 'Stocks', '${s.stock.length} articles', const StocksScreen()),
              _tile(context, Icons.show_chart, 'Finances', 'Ventes et dépenses', const FinancesScreen()),
              _tile(context, Icons.checklist, 'Tâches', '${s.tasks.where((x) => !x.done).length} à faire', const TasksScreen()),
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
            title: Text(title),
            subtitle: Text(sub),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
          ),
        ),
      );
}
