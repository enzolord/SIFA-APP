import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/diagnosis.dart';
import '../services/analysis_store.dart';
import '../services/triage.dart';
import '../theme/colors.dart';
import 'result_screen.dart';

/// Après la photo : l'éleveur coche ce qu'il observe dans la bande.
/// La photo seule ne suffit pas pour reconnaître une maladie ; ces signes
/// corrigent ou confirment ce que le modèle a vu.
class SignsScreen extends StatefulWidget {
  const SignsScreen({super.key, required this.photo, required this.photoProbs});
  final Uint8List photo;
  final List<double> photoProbs;

  @override
  State<SignsScreen> createState() => _SignsScreenState();
}

class _SignsScreenState extends State<SignsScreen> {
  final _chosen = <String>{};

  void _toggle(SignGroup group, Sign sign, bool on) {
    setState(() {
      if (!on) {
        _chosen.remove(sign.id);
        return;
      }
      if (sign.exclusive) {
        // « Tout va bien » : on garde seulement l'âge et le vaccin.
        _chosen.removeWhere((id) => !id.startsWith('age_') && id != 'vacc_nd');
      } else {
        _chosen.remove('none');
      }
      if (group.single) {
        for (final s in group.signs) {
          _chosen.remove(s.id);
        }
      }
      _chosen.add(sign.id);
    });
  }

  void _finish(Set<String> signs) {
    final r = Triage.combine(widget.photoProbs, signs);
    final d = Diagnosis(
      disease: r.disease,
      confidence: r.confidence,
      photo: widget.photo,
      photoProbs: widget.photoProbs,
      signs: signs,
      reliability: r.reliability,
    );
    AnalysisStore.instance.add(d);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ResultScreen(diagnosis: d)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Tx('Signes observés')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(widget.photo, width: 72, height: 72, fit: BoxFit.cover),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Tx(
                'Cochez ce que vous voyez dans la bande. Une photo seule peut tromper : ces signes rendent le résultat plus fiable.',
                style: t.bodyLarge,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          for (final g in signGroups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Tx(g.title, style: t.titleMedium),
            ),
            for (final s in g.signs)
              CheckboxListTile(
                value: _chosen.contains(s.id),
                onChanged: (v) => _toggle(g, s, v ?? false),
                title: Tx(s.label),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: SifaColors.brand,
              ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            onPressed: () => _finish(Set.of(_chosen)),
            child: const Tx('Voir le résultat'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _finish(const {}),
            child: const Tx('Passer cette étape'),
          ),
        ],
      ),
    );
  }
}
