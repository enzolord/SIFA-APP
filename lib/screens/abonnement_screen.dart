import 'package:flutter/material.dart';

import '../services/analytics.dart';
import '../services/auth_service.dart';
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
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(listenable: RemoteContent.instance, builder: (context, _) => _page(context, t));
  }

  Widget _plan2(TextTheme t, String key, String name, String fallbackDesc, bool best) {
    final f = RemoteContent.instance.section('formules');
    final m = f[key] is Map ? Map<String, dynamic>.from(f[key] as Map) : <String, dynamic>{};
    final desc = localized(m['desc']);
    final price = (m['prix'] as String?)?.trim() ?? '';
    return _plan(t, name, desc.isEmpty ? fallbackDesc : desc, price.isEmpty ? 'Prix bientôt communiqué' : price, best);
  }

  Widget _page(BuildContext context, TextTheme t) {
    final pay = localized(RemoteContent.instance.section('formules')['paiement']).trim();
    return Scaffold(
      appBar: AppBar(title: const Tx('Formules')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Tx('Vos 3 analyses gratuites sont utilisées', style: t.headlineSmall),
          const SizedBox(height: 6),
          Tx('Choisissez une formule pour continuer à analyser vos volailles.', style: t.bodyLarge),
          const SizedBox(height: 16),
          _plan2(t, 'mensuelle', 'Formule mensuelle', 'Analyses illimitées pour une ferme', false),
          const SizedBox(height: 12),
          _plan2(t, 'annuelle', 'Formule annuelle', 'Même formule, moins chère par mois', true),
          const SizedBox(height: 20),
          Tx('Comment payer', style: t.titleMedium),
          const SizedBox(height: 8),
          if (pay.isNotEmpty)
            Text(pay)
          else
            const Tx('1. Envoyez le montant par Mobile Money au numéro indiqué.\n'
                '2. Notre équipe confirme votre paiement.\n'
                '3. Vous recevez un code et l\'entrez ci-dessous.'),
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

  Widget _plan(TextTheme t, String name, String desc, String price, bool best) => Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: best ? SifaColors.brand : Colors.transparent, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Tx(name, style: t.titleMedium),
            const SizedBox(height: 4),
            Tx(desc, style: t.bodyMedium),
            const SizedBox(height: 10),
            Tx(price, style: t.headlineSmall),
          ]),
        ),
      );
}
