import 'package:flutter/material.dart';

import '../services/farm_store.dart';
import '../services/session.dart';
import '../theme/colors.dart';
import '../widgets/disclaimer.dart';
import '../widgets/sifa_mark.dart';

/// Connexion -> ferme -> consentement, en une seule pile de pages.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _farm = TextEditingController();
  final _count = TextEditingController();
  FlockType _type = FlockType.broiler;
  bool _consent = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _farm.dispose();
    _count.dispose();
    super.dispose();
  }

  bool get _stepValid => switch (_step) {
        0 => _phone.text.replaceAll(' ', '').length >= 9 && _code.text.length == 6,
        1 => _farm.text.trim().isNotEmpty && (int.tryParse(_count.text) ?? 0) > 0,
        _ => _consent,
      };

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      FarmStore.instance.addBand('Bande 1', _type, int.parse(_count.text));
      Session.instance.completeOnboarding(
        phone: '+237 ${_phone.text.trim()}',
        farmName: _farm.text.trim(),
        type: _type,
        headcount: int.parse(_count.text),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const SifaMark(size: 48),
              const SizedBox(width: 12),
              Text('SIFA', style: t.displayMedium),
              const Spacer(),
              Text('Étape ${_step + 1} sur 3', style: t.bodyMedium),
            ]),
            const SizedBox(height: 28),
            Expanded(
              child: SingleChildScrollView(
                child: switch (_step) {
                  0 => _login(t),
                  1 => _farmStep(t),
                  _ => _consentStep(t),
                },
              ),
            ),
            FilledButton(
              onPressed: _stepValid ? _next : null,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              child: Text(switch (_step) {
                0 => 'Se connecter',
                1 => 'Continuer',
                _ => "J'accepte et je commence",
              }),
            ),
            if (_step > 0)
              TextButton(
                onPressed: () => setState(() => _step--),
                child: const Text('Retour'),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _login(TextTheme t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Prenez en photo la fiente de vos volailles. SIFA vous dit si elles sont saines ou malades.',
            style: t.bodyLarge),
        const SizedBox(height: 24),
        Text('Numéro de téléphone', style: t.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixText: '+237  ', hintText: '6 XX XX XX XX', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        Text('Code reçu par SMS', style: t.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 22, letterSpacing: 6),
          decoration: const InputDecoration(hintText: '000000', counterText: '', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        Text('Version de démonstration : tout code à 6 chiffres est accepté.',
            style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
      ]);

  Widget _farmStep(TextTheme t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Votre élevage', style: t.headlineSmall),
        const SizedBox(height: 20),
        Text("Nom de la ferme", style: t.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _farm,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'Ferme Mbarga', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        Text('Type de volailles', style: t.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<FlockType>(
          segments: [
            for (final f in FlockType.values) ButtonSegment(value: f, label: Text(f.label)),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 20),
        Text('Nombre de volailles', style: t.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _count,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: '500', border: OutlineInputBorder()),
        ),
      ]);

  Widget _consentStep(TextTheme t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Avant d\'analyser, SIFA a besoin de votre accord clair.', style: t.headlineSmall),
        const SizedBox(height: 16),
        const Text("• Vos photos servent à analyser la santé de vos volailles.\n"
            "• Avec votre accord, elles peuvent aussi aider à améliorer SIFA, sans votre nom.\n"
            "• Vous pouvez retirer votre accord à tout moment dans Profil."),
        const SizedBox(height: 16),
        const Disclaimer(),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _consent,
          activeColor: SifaColors.brand,
          onChanged: (v) => setState(() => _consent = v ?? false),
          title: const Text("J'ai compris et j'accepte que mes photos soient analysées."),
        ),
      ]);
}
