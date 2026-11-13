import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/l10n.dart';
import '../../services/analytics.dart';
import '../../services/farm_store.dart';
import '../../services/session.dart';

/// Texte court du rapport d'une bande (affiché et encodé dans le code QR).
String bandReport(Band b, {FarmStore? store, DateTime? now}) {
  final s = store ?? FarmStore.instance;
  final d = now ?? DateTime.now();
  String date(DateTime x) => '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
  final rows = <String>[
    'SIFA - ${Session.instance.farmName.isEmpty ? tr('Ma ferme') : Session.instance.farmName}',
    '${b.name} (${tr(b.type.label)}) - ${date(d)}',
    trf('Jour {0} : {1} vivants sur {2}', [b.day, s.alive(b), b.initialCount]),
    trf('Mortalité : {0} %', [s.mortalityPct(b).dec1]),
    trf('Aliment : {0} kg', [s.feedTotal(b).round()]),
  ];
  if (b.type == FlockType.layer) {
    final r = s.layingRate(b);
    if (r != null) rows.add(trf('Taux de ponte : {0} %', [r.round()]));
  } else {
    final w = s.lastWeight(b);
    final ic = s.feedConversion(b);
    if (w != null) rows.add(trf('Poids moyen : {0} g', [w.round()]));
    if (ic != null) rows.add(trf('Indice de consommation : {0}', [ic.toStringAsFixed(2)]));
  }
  rows.add(trf('Ventes {0} - Dépenses {1} = {2} FCFA', [fcfa(s.salesOf(b)), fcfa(s.expensesOf(b)), fcfa(s.profitOf(b))]));
  final care = s.healthOf(b);
  if (care.isNotEmpty) rows.add(trf('Soins : {0}', [care.take(3).map((h) => h.product).join(', ')]));
  final wait = care.where((h) => h.inWithdrawal).toList();
  if (wait.isNotEmpty) {
    final end = wait.map((h) => h.withdrawalEnd).reduce((a, c) => a.isAfter(c) ? a : c);
    rows.add(trf("Ne pas vendre avant le {0}", [date(end)]));
  }
  return rows.join('\n');
}

/// Rapport d'une bande avec code QR : à montrer à un vétérinaire, un acheteur ou un technicien,
/// qui le lit avec n'importe quel lecteur de code QR.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Band? _band;

  @override
  void initState() {
    super.initState();
    final b = FarmStore.instance.bands;
    _band = b.isEmpty ? null : b.first;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final bands = FarmStore.instance.bands;
    final b = _band;
    return Scaffold(
      appBar: AppBar(title: const Tx('Rapport de bande')),
      body: b == null
          ? const Center(child: Tx("Ajoutez d'abord une bande."))
          : ListenableBuilder(
              listenable: FarmStore.instance,
              builder: (context, _) {
                final text = bandReport(b);
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (bands.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<Band>(
                          value: b,
                          decoration: InputDecoration(labelText: tr('Bande'), border: const OutlineInputBorder()),
                          items: [for (final x in bands) DropdownMenuItem(value: x, child: Text(x.name))],
                          onChanged: (x) => setState(() => _band = x),
                        ),
                      ),
                    Center(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(12),
                        child: QrImageView(data: text, size: 240, backgroundColor: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(text, style: t.bodyMedium))),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        Analytics.instance.action('ferme:rapport_copie');
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Rapport copié.'))));
                      },
                      icon: const Icon(Icons.copy),
                      label: const Tx('Copier le rapport'),
                    ),
                    const SizedBox(height: 12),
                    Tx("Scannez le code avec n'importe quel lecteur de code QR pour lire ce rapport.", style: t.bodySmall),
                  ],
                );
              },
            ),
    );
  }
}
