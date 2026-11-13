import 'package:flutter/material.dart';

import '../data/pricing.dart';
import '../services/analytics.dart';
import '../services/auth_service.dart';
import '../services/entitlement.dart';
import '../services/remote_content.dart';
import '../theme/colors.dart';
import '../l10n/l10n.dart';

class AbonnementScreen extends StatefulWidget {
  const AbonnementScreen({super.key});

  @override
  State<AbonnementScreen> createState() => _AbonnementScreenState();
}

class _AbonnementScreenState extends State<AbonnementScreen> {
  final _code = TextEditingController();
  String? _msg;
  int _tab = 0; // 0 analyse, 1 gestion, 2 pack complet
  String? _choice; // identifiant de l'offre choisie
  String _packA = 'solo';
  int _packG = 1;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  bool _busy = false;

  /// Active le code saisi sur le serveur (fonction activer_code, réservée aux comptes connectés).
  Future<void> _activate() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _msg = "Saisissez votre code d'activation.");
      return;
    }
    final auth = AuthService.instance;
    final client = auth.client;
    if (client == null || !auth.signedIn) {
      setState(() => _msg = "Connectez-vous avec Google (onglet Profil) pour activer un code.");
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await client.rpc('activer_code', params: {'p_code': code});
      Analytics.instance.action('code_active');
      await Entitlement.instance.refresh();
      if (!mounted) return;
      setState(() => _msg = 'Formule activée. Merci !');
    } catch (e) {
      if (!mounted) return;
      setState(() => _msg = 'Code invalide ou déjà utilisé.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: Listenable.merge([RemoteContent.instance, Entitlement.instance]), builder: (context, _) => _page(context, Theme.of(context).textTheme));
  }

  Pricing get _pricing => Pricing.fromRemote(RemoteContent.instance.section('tarifs'));

  void _pick(String id, {bool available = true}) {
    if (!available) {
      setState(() => _msg = 'La gestion de ferme arrive bientôt. Vous serez prévenu dès qu\'elle sera disponible.');
      return;
    }
    Analytics.instance.action('offre:$id');
    setState(() {
      _choice = id;
      _msg = null;
    });
  }

  Widget _currentPlan(TextTheme t, Pricing p) {
    final e = Entitlement.instance;
    final id = e.offerId;
    final name = id == null ? null : (id == 'mensuelle' || id == 'annuelle' ? tr('Ancienne formule') : p.lookup(id)?.$1);
    final lim = e.limit;
    final line = lim == null
        ? tr('Analyses illimitées')
        : (e.isFree
            ? trf('Analyses gratuites utilisées : {0} sur {1}', [e.used, lim])
            : trf('Analyses utilisées ce mois : {0} sur {1}', [e.used, lim]));
    final until = e.until;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: SifaColors.brand.withValues(alpha: .08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Tx('Votre formule actuelle', style: t.bodySmall),
          const SizedBox(height: 2),
          Text(name ?? tr('Essai gratuit'), style: t.titleMedium),
          const SizedBox(height: 4),
          Text(line, style: t.bodyMedium),
          if (until != null) Text(trf('Valable jusqu\'au {0}', ['${until.day.toString().padLeft(2, '0')}/${until.month.toString().padLeft(2, '0')}/${until.year}']), style: t.bodySmall),
        ]),
      ),
    );
  }

  Widget _offer(TextTheme t, {required String id, required String name, required String line, required String price, String? sub, bool enabled = true, bool onQuote = false}) {
    final selected = _choice == id;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? SifaColors.brand : Colors.transparent, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _pick(id, available: enabled),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: t.titleMedium),
                const SizedBox(height: 4),
                Text(line, style: t.bodyMedium),
                if (sub != null) ...[const SizedBox(height: 2), Text(sub, style: t.bodySmall)],
              ]),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(price, style: onQuote ? t.titleMedium : t.titleLarge?.copyWith(color: SifaColors.brand)),
              if (!onQuote) Tx('par mois', style: t.bodySmall),
            ]),
            if (selected) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check_circle_rounded, color: SifaColors.brand)),
          ]),
        ),
      ),
    );
  }

  List<Widget> _analysisTab(TextTheme t, Pricing p) => [
        for (final a in p.packs)
          _offer(
            t,
            id: a.id,
            name: a.name,
            line: a.accountsAndMore
                ? trf('{0} comptes et plus · {1} analyses par mois', [a.accounts, a.analyses])
                : trf(a.accounts == 1 ? '{0} compte · {1} analyses par mois' : '{0} comptes · {1} analyses par mois', [a.accounts, a.analyses]),
            price: fcfa(a.price),
            sub: trf('Soit {0} par analyse', [fcfa(a.pricePerAnalysis)]),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Tx('Options', style: t.titleSmall),
              const SizedBox(height: 6),
              Text(trf('+ 1 compte : {0} par mois', [fcfa(p.extraAccount)])),
              Text(trf('+ {0} analyses : {1} ({2} par analyse)', [p.extraAnalysesCount, fcfa(p.extraAnalyses), fcfa((p.extraAnalyses / p.extraAnalysesCount).round())])),
            ]),
          ),
        ),
      ];

  String _range(FarmTier x) => x.max == null ? trf('Plus de {0} sujets', [x.min - 1]) : trf('{0} à {1} sujets', [x.min, x.max!]);

  List<Widget> _farmTab(TextTheme t, Pricing p) => [
        if (!p.farmManagementAvailable)
          Card(
            color: SifaColors.warn.withValues(alpha: .12),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Tx('La gestion de ferme arrive bientôt. Vous pouvez déjà voir les tarifs.'),
            ),
          ),
        const SizedBox(height: 4),
        for (final x in p.tiers)
          _offer(
            t,
            id: x.id,
            name: x.name,
            line: _range(x),
            price: x.onQuote ? tr('Sur devis') : fcfa(x.price!),
            onQuote: x.onQuote,
            enabled: p.farmManagementAvailable && !x.onQuote,
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Tx('Inclus dans la gestion de ferme', style: t.titleSmall),
              const SizedBox(height: 6),
              Tx('Achat des poussins, aliment, santé, dépenses, ventes, stocks, clients, rentabilité par bande, rapports QR.'),
              const SizedBox(height: 4),
              Text(trf('{0} comptes inclus.', [p.farmAccounts])),
            ]),
          ),
        ),
      ];

  List<Widget> _packTab(TextTheme t, Pricing p) {
    final a = p.packByKey(_packA);
    final g = p.tier(_packG);
    final d = p.deal(a, g);
    return [
      if (!p.farmManagementAvailable)
        Card(
          color: SifaColors.warn.withValues(alpha: .12),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Tx('Le pack complet arrive avec la gestion de ferme. Vous pouvez déjà voir les tarifs.'),
          ),
        ),
      const SizedBox(height: 4),
      Text(trf('Analyse + gestion de ferme : −{0} %', [p.packDiscount]), style: t.titleMedium),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        value: _packA,
        decoration: InputDecoration(labelText: tr('Formule analyse'), border: const OutlineInputBorder()),
        items: [for (final x in p.packs) DropdownMenuItem(value: x.key, child: Text('${x.name} · ${fcfa(x.price)}'))],
        onChanged: (v) => setState(() => _packA = v ?? _packA),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
        value: _packG,
        decoration: InputDecoration(labelText: tr('Formule gestion de ferme'), border: const OutlineInputBorder()),
        items: [for (final x in p.tiers.where((x) => !x.onQuote)) DropdownMenuItem(value: x.n, child: Text('${x.name} · ${_range(x)}'))],
        onChanged: (v) => setState(() => _packG = v ?? _packG),
      ),
      const SizedBox(height: 12),
      if (d != null)
        _offer(
          t,
          id: d.id,
          name: trf('Pack {0} + {1}', [a.name.replaceFirst('Analyse ', ''), g.name]),
          line: trf('Au lieu de {0}', [fcfa(d.sum)]),
          price: fcfa(d.price),
          sub: trf('Vous économisez {0} par mois', [fcfa(d.saving)]),
          enabled: p.farmManagementAvailable,
        ),
      const SizedBox(height: 4),
      Tx('Combinaisons conseillées', style: t.titleSmall),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final f in Pricing.featured)
          ActionChip(
            label: Text('${p.packByKey(f.$1).name.replaceFirst('Analyse ', '')} + G${f.$2}'),
            onPressed: () => setState(() {
              _packA = f.$1;
              _packG = f.$2;
            }),
          ),
      ]),
    ];
  }

  Widget _page(BuildContext context, TextTheme t) {
    final p = _pricing;
    final pay = localized(RemoteContent.instance.section('formules')['paiement']).trim();
    final chosen = _choice == null ? null : p.lookup(_choice!);
    return Scaffold(
      appBar: AppBar(title: const Tx('Formules')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _currentPlan(t, p),
          Tx('Choisissez votre formule', style: t.headlineSmall),
          const SizedBox(height: 6),
          Tx('Analyse des fientes, gestion de ferme, ou les deux avec une réduction.', style: t.bodyLarge),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 0, label: Text(tr('Analyse'))),
              ButtonSegment(value: 1, label: Text(tr('Gestion'))),
              ButtonSegment(value: 2, label: Text(tr('Pack complet'))),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() {
              _tab = s.first;
              _msg = null;
            }),
          ),
          const SizedBox(height: 16),
          ...switch (_tab) { 0 => _analysisTab(t, p), 1 => _farmTab(t, p), _ => _packTab(t, p) },
          const SizedBox(height: 20),
          if (chosen != null) ...[
            Card(
              color: SifaColors.brand.withValues(alpha: .1),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded, color: SifaColors.brand),
                  const SizedBox(width: 10),
                  Expanded(child: Text(trf('Votre choix : {0}, {1} par mois', [chosen.$1, fcfa(chosen.$2 ?? 0)]), style: t.titleSmall)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Tx('Comment payer', style: t.titleMedium),
          const SizedBox(height: 8),
          if (pay.isNotEmpty)
            Text(pay)
          else
            const Tx('1. Envoyez le montant par Mobile Money au numéro indiqué.\n'
                '2. Notre équipe confirme votre paiement.\n'
                '3. Vous recevez un code et l\'entrez ci-dessous.'),
          if (chosen != null) ...[
            const SizedBox(height: 8),
            Text(trf('Indiquez en référence : {0}', [chosen.$1]), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            decoration: InputDecoration(labelText: tr("Code d'activation"), border: const OutlineInputBorder()),
          ),
          if (_msg != null) ...[
            const SizedBox(height: 8),
            Tx(_msg!, style: t.bodyMedium?.copyWith(color: SifaColors.warn)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            onPressed: _busy ? null : _activate,
            child: const Tx('Activer ma formule'),
          ),
        ],
      ),
    );
  }
}
