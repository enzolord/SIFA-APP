import 'package:flutter/material.dart';

import '../../services/farm_store.dart';
import '../../services/session.dart';
import '../../theme/colors.dart';
import '../../widgets/kpi_card.dart';
import 'bands_screen.dart';
import 'entry_screen.dart';
import '../../services/analytics.dart';
import '../../services/entitlement.dart';
import '../../data/pricing.dart' as pr;
import '../../services/remote_content.dart';
import 'clients_screen.dart';
import 'finances_screen.dart';
import 'profit_screen.dart';
import 'report_screen.dart';
import 'health_screen.dart';
import 'performance_screen.dart';
import '../abonnement_screen.dart';
import 'stocks_screen.dart';
import 'tasks_screen.dart';
import '../../l10n/l10n.dart';

class FermeHub extends StatelessWidget {
  const FermeHub({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: Listenable.merge([FarmStore.instance, Entitlement.instance, RemoteContent.instance]),
      builder: (context, _) {
        if (!Entitlement.instance.farmAccess) return _locked(context, t);
        final s = FarmStore.instance;
        final pricing = pr.Pricing.fromRemote(RemoteContent.instance.section('tarifs'));
        final tier = Entitlement.instance.farmTier;
        final cap = tier == null ? null : pricing.tier(tier).max;
        final over = pricing.farmManagementAvailable && cap != null && s.totalPlaced > cap;
        final layers = s.bands.any((b) => b.type == FlockType.layer);
        final waiting = s.activeWithdrawals.length;
        final m = s.mortality7d;
        final margin = s.monthMargin;
        return Scaffold(
          appBar: AppBar(title: const Tx('Ma ferme')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Tx(Session.instance.farmLine, style: t.bodyMedium),
              if (over) ...[
                const SizedBox(height: 12),
                Card(
                  color: SifaColors.warn.withValues(alpha: .14),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(trf('Vous avez {0} sujets, au-delà de votre formule Gestion {1} (maximum {2}). Passez à la formule supérieure.', [s.totalPlaced, tier!, cap!])),
                  ),
                ),
              ],
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
                    label: "Délais d'attente",
                    value: '$waiting',
                    sub: waiting == 0 ? 'Aucune vente bloquée' : 'À respecter avant de vendre',
                    subColor: waiting == 0 ? SifaColors.ok : SifaColors.warn,
                  ),
                  if (layers)
                    KpiCard(label: 'Taux de ponte (7 jours)', value: _layRate(s))
                  else
                    KpiCard(label: 'Poids moyen', value: _avgWeight(s)),
                  KpiCard(
                    label: 'Marge du mois',
                    value: '${margin >= 0 ? '+' : ''}${fcfa(margin)}',
                    sub: 'FCFA',
                    subColor: margin >= 0 ? SifaColors.ok : SifaColors.danger,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _tile(context, Icons.groups, 'Bandes', trf('{0} en cours', [s.bands.length]), const BandsScreen(), 'BandsScreen'),
              _tile(context, Icons.edit_note, 'Saisie du jour', trf('{0} sur {1} saisies', [s.todayEntriesCount, s.bands.length]), const EntryScreen(), 'EntryScreen'),
              _tile(context, Icons.query_stats_rounded, 'Performances', layers ? 'Ponte, mortalité, aliment' : 'Poids, indice de consommation, mortalité', const PerformanceScreen(), 'PerformanceScreen'),
              _tile(context, Icons.medical_services_outlined, 'Santé et traitements', trf('{0} soins enregistrés', [s.health.length]), const HealthScreen(), 'HealthScreen'),
              _tile(context, Icons.inventory_2_outlined, 'Stocks', trf('{0} articles', [s.stock.length]), const StocksScreen(), 'StocksScreen'),
              _tile(context, Icons.show_chart, 'Finances', 'Ventes et dépenses', const FinancesScreen(), 'FinancesScreen'),
              _tile(context, Icons.people_outline, 'Clients', trf('{0} clients', [s.clients.length]), const ClientsScreen(), 'ClientsScreen'),
              _tile(context, Icons.payments_outlined, 'Rentabilité par bande', 'Marge de chaque bande', const ProfitScreen(), 'ProfitScreen'),
              _tile(context, Icons.qr_code_2_rounded, 'Rapport de bande', 'Résumé avec code QR', const ReportScreen(), 'ReportScreen'),
              _tile(context, Icons.checklist, 'Tâches', trf('{0} à faire', [s.tasks.where((x) => !x.done).length]), const TasksScreen(), 'TasksScreen'),
            ],
          ),
        );
      },
    );
  }

  static String _layRate(FarmStore s) {
    final r = [for (final b in s.bands.where((b) => b.type == FlockType.layer)) s.layingRate(b)].whereType<double>().toList();
    return r.isEmpty ? '—' : '${(r.reduce((a, b) => a + b) / r.length).round()} %';
  }

  static String _avgWeight(FarmStore s) {
    final w = [for (final b in s.bands) s.lastWeight(b)].whereType<double>().toList();
    return w.isEmpty ? '—' : '${(w.reduce((a, b) => a + b) / w.length).round()} g';
  }

  Widget _locked(BuildContext context, TextTheme t) => Scaffold(
        appBar: AppBar(title: const Tx('Ma ferme')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_outline_rounded, size: 52, color: SifaColors.brand),
              const SizedBox(height: 16),
              Tx('La gestion de ferme est incluse dans les formules Gestion et Pack complet.', textAlign: TextAlign.center, style: t.titleMedium),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  Analytics.instance.action('ferme:verrouille');
                  Navigator.of(context).push(MaterialPageRoute<void>(settings: const RouteSettings(name: 'AbonnementScreen'), builder: (_) => const AbonnementScreen()));
                },
                child: const Tx('Voir les formules'),
              ),
            ]),
          ),
        ),
      );

  Widget _tile(BuildContext context, IconData icon, String title, String sub, Widget page, String route) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          child: ListTile(
            leading: Icon(icon, color: SifaColors.brand),
            title: Tx(title),
            subtitle: Tx(sub),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(settings: RouteSettings(name: route), builder: (_) => page)),
          ),
        ),
      );
}
