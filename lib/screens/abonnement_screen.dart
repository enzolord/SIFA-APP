import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Tx('Formules')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Tx('Vos 3 analyses gratuites sont utilisées', style: t.headlineSmall),
          const SizedBox(height: 6),
          Tx('Choisissez une formule pour continuer à analyser vos volailles.', style: t.bodyLarge),
          const SizedBox(height: 16),
          _plan(t, 'Formule mensuelle', 'Analyses illimitées pour une ferme', '[PRIX] FCFA', false),
          const SizedBox(height: 12),
          _plan(t, 'Formule annuelle', 'Même formule, moins chère par mois', '[PRIX] FCFA', true),
          const SizedBox(height: 20),
          Tx('Comment payer', style: t.titleMedium),
          const SizedBox(height: 8),
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
            onPressed: () => setState(() => _msg = 'Activation disponible quand le serveur sera connecté.'),
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
