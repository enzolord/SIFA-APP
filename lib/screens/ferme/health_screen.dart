import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/analytics.dart';
import '../../services/farm_store.dart';
import '../../theme/colors.dart';
import '../../widgets/form_dialog.dart';

String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Journal de santé : vaccins et traitements donnés à chaque bande, avec le délai d'attente avant vente.
class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  static const _kinds = {
    HealthKind.vaccine: ('Vaccin', Icons.vaccines_rounded),
    HealthKind.treatment: ('Traitement', Icons.medication_rounded),
    HealthKind.other: ('Autre soin', Icons.healing_rounded),
  };

  Future<Band?> _pickBand(BuildContext context) async {
    final bands = FarmStore.instance.bands;
    if (bands.length <= 1) return bands.isEmpty ? null : bands.first;
    return showDialog<Band>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Tx('Quelle bande ?'),
        children: [for (final b in bands) SimpleDialogOption(onPressed: () => Navigator.pop(context, b), child: Tx(b.name))],
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    if (FarmStore.instance.bands.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Tx("Ajoutez d'abord une bande.")));
      return;
    }
    final kind = await showModalBottomSheet<HealthKind>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final e in _kinds.entries)
            ListTile(leading: Icon(e.value.$2, color: SifaColors.brand), title: Tx(e.value.$1), onTap: () => Navigator.pop(context, e.key)),
        ]),
      ),
    );
    if (kind == null || !context.mounted) return;
    final band = await _pickBand(context);
    if (band == null || !context.mounted) return;
    final v = await showFormDialog(context, title: _kinds[kind]!.$1, fields: [
      FieldSpec(kind == HealthKind.vaccine ? 'Vaccin' : 'Produit', hint: kind == HealthKind.vaccine ? 'Gumboro, Newcastle...' : 'Nom du médicament'),
      if (kind != HealthKind.vaccine) const FieldSpec("Délai d'attente (jours)", number: true, hint: 'Indiqué sur la notice, 0 si aucun'),
      const FieldSpec('Note', hint: 'Dose, durée, vétérinaire...'),
    ]);
    if (v == null || v[0].isEmpty) return;
    final withdrawal = kind == HealthKind.vaccine ? 0 : toNum(v[1]).round().clamp(0, 365);
    FarmStore.instance.addHealth(HealthEvent(
      bandId: band.id,
      date: DateTime.now(),
      kind: kind,
      product: v[0],
      note: v.last,
      withdrawalDays: withdrawal,
    ));
    Analytics.instance.action('ferme:sante_ajout');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: FarmStore.instance,
      builder: (context, _) {
        final s = FarmStore.instance;
        final all = [...s.health]..sort((a, b) => b.date.compareTo(a.date));
        final wait = s.activeWithdrawals.toList();
        String bandName(int id) => s.bands.where((b) => b.id == id).map((b) => b.name).firstOrNull ?? '—';
        return Scaffold(
          appBar: AppBar(title: const Tx('Santé et traitements')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Tx('Ajouter'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (wait.isNotEmpty)
                Card(
                  color: SifaColors.warn.withValues(alpha: .14),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Tx("Délai d'attente en cours", style: t.titleSmall),
                      const SizedBox(height: 4),
                      const Tx("Ne vendez ni œufs ni poulets de ces bandes avant la date indiquée."),
                      const SizedBox(height: 8),
                      for (final h in wait)
                        Text(trf('{0} · {1} : jusqu\'au {2}', [bandName(h.bandId), h.product, _date(h.withdrawalEnd)]), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              if (all.isEmpty)
                const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: Tx('Aucun vaccin ni traitement enregistré.')))
              else
                for (final h in all)
                  Dismissible(
                    key: ObjectKey(h),
                    direction: DismissDirection.endToStart,
                    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: SifaColors.danger, child: const Icon(Icons.delete, color: Colors.white)),
                    onDismissed: (_) => FarmStore.instance.removeHealth(h),
                    child: Card(
                      child: ListTile(
                        leading: Icon(_kinds[h.kind]!.$2, color: SifaColors.brand),
                        title: Text(h.product),
                        subtitle: Text([
                          '${bandName(h.bandId)} · ${_date(h.date)}',
                          if (h.withdrawalDays > 0) trf("Délai d'attente : {0} jours", [h.withdrawalDays]),
                          if (h.note.isNotEmpty) h.note,
                        ].join('\n')),
                        isThreeLine: h.withdrawalDays > 0 || h.note.isNotEmpty,
                        trailing: h.inWithdrawal ? const Icon(Icons.hourglass_bottom_rounded, color: SifaColors.warn) : null,
                      ),
                    ),
                  ),
              const SizedBox(height: 12),
              Tx('Glissez vers la gauche pour supprimer une ligne. Le délai d\'attente est celui de la notice du produit ; en cas de doute, demandez à un vétérinaire.', style: t.bodySmall),
            ],
          ),
        );
      },
    );
  }
}
