import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/diagnosis.dart';
import '../services/analysis_store.dart';
import '../services/triage.dart';
import '../theme/colors.dart';
import 'result_screen.dart';

/// Après la photo : quelques questions courtes, choisies selon la photo et les réponses
/// déjà données (4 à 8 questions, pas une liste de 17 cases). La photo seule peut tromper ;
/// les réponses la confirment ou la corrigent.
class SignsScreen extends StatefulWidget {
  const SignsScreen({super.key, required this.photo, required this.photoProbs});
  final Uint8List photo;
  final List<double> photoProbs;

  @override
  State<SignsScreen> createState() => _SignsScreenState();
}

class _SignsScreenState extends State<SignsScreen> {
  /// id de question -> index de la réponse, dans l'ordre où elles ont été données.
  final _answers = <String, int>{};

  Question? get _current => Questionnaire.next(widget.photoProbs, _answers);

  void _answer(Question q, int index) {
    setState(() => _answers[q.id] = index);
    if (Questionnaire.next(widget.photoProbs, _answers) == null) _finish();
  }

  void _back() {
    if (_answers.isEmpty) return;
    setState(() => _answers.remove(_answers.keys.last));
  }

  void _finish() {
    final signs = Questionnaire.signsOf(_answers);
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
    final q = _current;
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
                'Quelques questions sur vos poulets rendent le résultat plus fiable.',
                style: t.bodyLarge,
              ),
            ),
          ]),
          const SizedBox(height: 20),
          if (q != null) ...[
            Tx(q.text, style: t.titleLarge),
            const SizedBox(height: 12),
            for (var i = 0; i < q.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: () => _answer(q, i),
                  child: Tx(q.options[i].label),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Row(children: [
            if (_answers.isNotEmpty) TextButton(onPressed: _back, child: const Tx('Retour')),
            const Spacer(),
            TextButton(onPressed: _finish, child: const Tx('Voir le résultat maintenant')),
          ]),
        ],
      ),
    );
  }
}
