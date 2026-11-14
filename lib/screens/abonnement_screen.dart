import 'package:flutter/material.dart';

import '../data/pricing.dart';
import '../services/analytics.dart';
import '../services/auth_service.dart';
import '../services/entitlement.dart';
import '../services/payment_service.dart';
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
    _promo.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool _busy = false;

  // Paiement Mobile Money (Campay)
  final _phone = TextEditingController();
  int _months = 1;
  bool _paying = false;
  String? _payInfo; // consigne affichée pendant l'attente
  String? _payOk;
  String? _payErr;

  Future<void> _pay() async {
    final offer = _choice;
    if (offer == null || _paying) return;
    setState(() {
      _paying = true;
      _payErr = null;
      _payOk = null;
      _payInfo = null;
    });
    try {
      final s = await PaymentService.start(offer: offer, months: _months, phone: _phone.text, promo: _promoCode);
      Analytics.instance.action('paiement_demarre');
      var status = s.status;
      if (status == 'en_attente') {
        if (mounted) {
          setState(() => _payInfo = s.ussd == null
              ? tr('Validez le paiement sur votre téléphone avec votre code secret. Cela peut prendre une minute.')
              : trf('Validez le paiement sur votre téléphone avec votre code secret. Si rien n\'apparaît, composez {0}.', [s.ussd!]));
        }
        String? reason;
        for (var i = 0; i < 45 && status == 'en_attente' && mounted; i++) {
          await Future<void>.delayed(const Duration(seconds: 4));
          try {
            (status, reason) = await PaymentService.check(s.id);
          } on PaymentException {
            // coupure passagère : on réessaie au tour suivant
          }
        }
        if (status == 'echoue') throw PaymentException(reason == null || reason.isEmpty ? 'Paiement refusé ou annulé.' : reason);
      }
      if (status == 'reussi') {
        Analytics.instance.action('paiement_reussi');
        await Entitlement.instance.refresh();
        if (mounted) setState(() => _payOk = 'Paiement reçu. Votre formule est active. Merci !');
      } else if (mounted) {
        setState(() => _payErr = 'Nous n\'avons pas encore reçu la confirmation. Si le montant a été débité, votre formule sera activée automatiquement dans quelques minutes.');
      }
    } on PaymentException catch (e) {
      if (mounted) setState(() => _payErr = e.message);
    } finally {
      if (mounted) {
        setState(() {
          _paying = false;
          _payInfo = null;
        });
      }
    }
  }

  // Code de réduction appliqué (pourcentage) : il ne change que le prix affiché.
  final _promo = TextEditingController();
  int _discount = 0;
  String _promoCode = '';
  String? _promoMsg;

  Future<void> _applyPromo() async {
    final code = _promo.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final client = AuthService.instance.client;
    if (client == null) {
      setState(() => _promoMsg = 'Connexion impossible pour le moment. Vérifiez votre réseau.');
      return;
    }
    try {
      final rows = await client.rpc('verifier_promo', params: {'p_code': code});
      final list = rows is List ? rows : const [];
      if (!mounted) return;
      if (list.isEmpty) {
        setState(() {
          _discount = 0;
          _promoCode = '';
          _promoMsg = 'Code de réduction invalide ou expiré.';
        });
        return;
      }
      final pct = ((list.first as Map)['reduction'] as num).round().clamp(1, 100);
      Analytics.instance.track('promo_applique', {'code': code, 'offre': _choice});
      setState(() {
        _discount = pct;
        _promoCode = code;
        _promoMsg = null;
      });
    } catch (_) {
      if (mounted) setState(() => _promoMsg = 'Connexion impossible pour le moment. Vérifiez votre réseau.');
    }
  }

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
      _payErr = null;
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

  String _p(int v) => fcfa(discounted(v, _discount));

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
            price: _p(a.price),
            sub: trf('Soit {0} par analyse', [fcfa((discounted(a.price, _discount) / a.analyses).round())]),
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
            price: x.onQuote ? tr('Sur devis') : _p(x.price!),
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
          price: _p(d.price),
          sub: trf('Vous économisez {0} par mois', [fcfa(d.sum - discounted(d.price, _discount))]),
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
                  Expanded(child: Text(trf('Votre choix : {0}, {1} par mois', [chosen.$1, fcfa(discounted(chosen.$2 ?? 0, _discount))]), style: t.titleSmall)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Tx('Code de réduction', style: t.titleMedium),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                controller: _promo,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: tr('Code promo'), border: const OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 56)), onPressed: _applyPromo, child: const Tx('Appliquer')),
          ]),
          if (_discount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(trf('Code {0} appliqué : −{1} % sur les prix affichés.', [_promoCode, _discount]), style: t.bodyMedium?.copyWith(color: SifaColors.ok, fontWeight: FontWeight.w600)),
            ),
          if (_promoMsg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Tx(_promoMsg!, style: t.bodyMedium?.copyWith(color: SifaColors.warn))),
          const SizedBox(height: 20),
          Tx('Payer par Mobile Money', style: t.titleMedium),
          const SizedBox(height: 8),
          if (chosen == null)
            const Tx('Choisissez une formule ci-dessus pour payer avec MTN Mobile Money ou Orange Money.')
          else ...[
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _months,
                  decoration: InputDecoration(labelText: tr('Durée'), border: const OutlineInputBorder()),
                  items: [for (final m in const [1, 3, 6, 12]) DropdownMenuItem(value: m, child: Text(m == 1 ? tr('1 mois') : trf('{0} mois', [m])))],
                  onChanged: _paying ? null : (v) => setState(() => _months = v ?? 1),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              enabled: !_paying,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: tr('Numéro MTN ou Orange'), hintText: '6XX XX XX XX', prefixText: '+237 ', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              onPressed: _paying ? null : _pay,
              icon: _paying ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.phone_android_rounded),
              label: Text(trf('Payer {0}', [fcfa(discounted(chosen.$2 ?? 0, _discount) * _months)])),
            ),
            if (_payInfo != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_payInfo!, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
            if (_payErr != null) Padding(padding: const EdgeInsets.only(top: 10), child: Tx(_payErr!, style: t.bodyMedium?.copyWith(color: SifaColors.warn))),
            if (_payOk != null) Padding(padding: const EdgeInsets.only(top: 10), child: Tx(_payOk!, style: t.bodyMedium?.copyWith(color: SifaColors.ok, fontWeight: FontWeight.w600))),
            const SizedBox(height: 6),
            Tx('Un compte Google connecté est nécessaire. La formule s\'active toute seule dès que le paiement est confirmé.', style: t.bodySmall),
          ],
          if (pay.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(pay, style: t.bodySmall),
          ],
          const SizedBox(height: 20),
          Tx("J'ai un code d'accès", style: t.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            decoration: InputDecoration(labelText: tr("Code d'activation ou code d'accès"), border: const OutlineInputBorder()),
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
