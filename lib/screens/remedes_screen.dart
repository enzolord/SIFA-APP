import 'package:flutter/material.dart';

import '../data/knowledge.dart';
import '../l10n/l10n.dart';
import '../models/diagnosis.dart';
import '../theme/colors.dart';

/// Fiche d'une maladie : la reconnaître, la voie vétérinaire, la voie artisanale, la prévention.
class RemedesScreen extends StatelessWidget {
  const RemedesScreen({super.key, required this.disease});
  final Disease disease;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final info = diseaseInfo[disease]!;
    final sheet = diseaseSheets[disease]!;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Tx(info.shortName),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: tr('Reconnaître')),
              Tab(text: tr('Vétérinaire')),
              Tab(text: tr('Artisanal')),
              Tab(text: tr('Prévention')),
            ],
          ),
        ),
        body: TabBarView(children: [
          _page([
            for (final i in sheet.recognize) _item(t, i),
            _title(t, 'À ne pas confondre avec'),
            _bullets(t, sheet.confusions),
            if (sheet.humanRisk != null) ...[
              _title(t, "Risque pour l'homme"),
              Tx(sheet.humanRisk!, style: t.bodyLarge),
            ],
            _pending(t),
          ]),
          _page([
            _title(t, 'À faire maintenant'),
            _numbered(t, sheet.now),
            _title(t, 'Traitement vétérinaire'),
            for (final i in sheet.scientific) _item(t, i),
            _note(
              t,
              SifaColors.dangerSoft,
              SifaColors.danger,
              Icons.warning_rounded,
              "Les doses indiquées sont celles des notices. Faites confirmer le produit et la dose par votre vétérinaire, et respectez les délais d'attente avant de vendre viande et œufs.",
            ),
            _pending(t),
          ]),
          _page([
            _note(
              t,
              SifaColors.yolkSoft,
              SifaColors.ink,
              Icons.info_outline,
              "Les remèdes artisanaux aident parfois, mais ils sont moins sûrs qu'un traitement vétérinaire. Chaque conseil porte son niveau de preuve.",
            ),
            const SizedBox(height: 12),
            for (final i in sheet.artisanal) _item(t, i),
            _pending(t),
          ]),
          _page([
            _bullets(t, sheet.prevention),
            _pending(t),
          ]),
        ]),
      ),
    );
  }

  Widget _page(List<Widget> children) => ListView(padding: const EdgeInsets.all(20), children: children);

  Widget _title(TextTheme t, String s) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Tx(s, style: t.titleMedium),
      );

  Widget _item(TextTheme t, KbItem i) {
    final ev = i.evidence;
    final (fg, bg) = switch (ev) {
      Evidence.proven => (SifaColors.ok, SifaColors.okSoft),
      Evidence.limited => (SifaColors.warn, SifaColors.warnSoft),
      Evidence.dangerous => (SifaColors.danger, SifaColors.dangerSoft),
      _ => (SifaColors.inkMuted, SifaColors.surfaceSunken),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Tx(i.title, style: t.titleSmall),
            if (ev != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                child: Tx(evidenceLabel[ev]!, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
            const SizedBox(height: 8),
            Tx(i.body, style: t.bodyLarge),
          ]),
        ),
      ),
    );
  }

  Widget _bullets(TextTheme t, List<String> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('• ${tr(s)}', style: t.bodyLarge),
            ),
        ],
      );

  Widget _numbered(TextTheme t, List<String> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${i + 1}. ${tr(items[i])}', style: t.bodyLarge),
            ),
        ],
      );

  Widget _note(TextTheme t, Color bg, Color fg, IconData icon, String text) => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Tx(text, style: t.bodyMedium?.copyWith(color: SifaColors.ink))),
        ]),
      );

  Widget _pending(TextTheme t) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Tx(kbPendingValidation, style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
      );
}
