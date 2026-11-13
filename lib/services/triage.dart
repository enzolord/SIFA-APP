import 'dart:math' as math;

import '../models/diagnosis.dart';

/// Signe clinique que l'éleveur peut cocher après la photo.
///
/// [w] : poids ajouté au score de chaque maladie quand le signe est présent
/// (positif = le signe va dans le sens de la maladie, négatif = il la rend moins probable).
/// Ces poids traduisent les manuels vétérinaires (MSD, OMSA, FAO, ACIAR) en une règle
/// simple. Ce ne sont pas des valeurs mesurées : À VALIDER PAR LE VÉTÉRINAIRE RÉFÉRENT.
class Sign {
  const Sign(this.id, this.label, this.w, {this.redFlag = false, this.exclusive = false});
  final String id;
  final String label;

  /// Ordre : sain, coccidiose, salmonellose, Newcastle (= Disease.values).
  final List<double> w;

  /// Signe d'alerte : maladie contagieuse grave possible, quel que soit le résultat photo.
  final bool redFlag;

  /// Signe qui décoche tous les autres (« tout va bien »).
  final bool exclusive;
}

class SignGroup {
  const SignGroup(this.title, this.signs, {this.single = false});
  final String title;
  final List<Sign> signs;

  /// Un seul choix possible dans le groupe (âge).
  final bool single;
}

//                                             sain  cocci salmo  ND
const signGroups = <SignGroup>[
  SignGroup('Âge des oiseaux', single: true, [
    Sign('age_chick', 'Poussins de moins de 3 semaines', [0, -0.6, 1.0, 0]),
    Sign('age_young', 'Jeunes de 3 à 8 semaines', [0, 0.8, -0.2, 0]),
    Sign('age_adult', 'Adultes ou pondeuses', [0, -0.5, 0.3, 0]),
  ]),
  SignGroup('Fientes', [
    Sign('blood', 'Sang dans les fientes', [-2.0, 2.0, -0.5, -0.5]),
    Sign('white_vent', 'Fientes blanches qui collent au cloaque', [-1.5, -0.3, 1.5, 0.2]),
    Sign('green', 'Diarrhée verte et liquide', [-1.5, -0.3, 0.4, 1.0]),
    Sign('yellow', 'Diarrhée jaune', [-1.5, 0, 1.0, 0]),
  ]),
  SignGroup('Comportement', [
    Sign('huddle', 'Oiseaux en boule, plumes ébouriffées', [-1.5, 0.3, 0.3, 0.3]),
    Sign('anorexia', 'Ne mangent presque plus', [-1.5, 0.3, 0.3, 0.3]),
    Sign('thirst', 'Boivent beaucoup', [-0.5, 0.4, 0, 0]),
  ]),
  SignGroup('Respiration, nerfs, tête', [
    Sign('resp', 'Toux, éternuements, respiration difficile', [-1.5, -0.7, 0.2, 1.5]),
    Sign('nervous', 'Cou tordu, tremblements ou paralysie', [-2.5, -1.0, -1.0, 2.5], redFlag: true),
    Sign('head', 'Tête ou yeux gonflés', [-1.5, -0.5, 0, 1.0]),
  ]),
  SignGroup('Ponte', [
    Sign('eggs', 'Chute de ponte, œufs déformés ou à coquille molle', [-1.0, 0, 0.3, 1.2]),
  ]),
  SignGroup('Mortalité', [
    Sign('death_fast', 'Beaucoup de morts en 1 à 3 jours, à tous les âges', [-3.0, 0.2, 0.5, 1.5], redFlag: true),
    Sign('death_chicks', 'Morts surtout chez les poussins', [-2.0, 0.3, 1.2, 0]),
  ]),
  SignGroup('Vaccination', [
    Sign('vacc_nd', 'Vaccinés contre Newcastle depuis moins de 4 mois', [0, 0, 0, -1.2]),
  ]),
  SignGroup('Rien à signaler', [
    Sign('none', 'Aucun de ces signes : les oiseaux vont bien', [1.5, -0.7, -0.7, -0.7], exclusive: true),
  ]),
];

final Map<String, Sign> signsById = {
  for (final g in signGroups)
    for (final s in g.signs) s.id: s,
};

/// Signes qui renseignent vraiment sur une maladie (l'âge et le vaccin ne comptent pas).
const _contextOnly = {'age_chick', 'age_young', 'age_adult', 'vacc_nd'};

class TriageResult {
  const TriageResult({
    required this.disease,
    required this.confidence,
    required this.probs,
    required this.reliability,
    required this.redFlag,
    required this.clinicalSigns,
    required this.signsAgree,
  });

  final Disease disease;
  final double confidence;

  /// Probabilités finales, dans l'ordre de [Disease.values].
  final List<double> probs;
  final Reliability reliability;
  final bool redFlag;

  /// Nombre de signes cliniques cochés (hors âge et vaccin).
  final int clinicalSigns;

  /// null : pas de signe clinique coché ; true : les signes pointent vers la même
  /// maladie que la photo ; false : ils pointent ailleurs.
  final bool? signsAgree;
}

class Triage {
  /// Poids donné à la photo. Inférieur à 1 : l'image seule est fragile (éclairage,
  /// cadrage, objet qui n'est pas une fiente), les signes doivent pouvoir la corriger.
  static const photoWeight = 0.7;

  static List<double> _softmax(List<double> logits) {
    final m = logits.reduce(math.max);
    final e = [for (final l in logits) math.exp(l - m)];
    final s = e.reduce((a, b) => a + b);
    return [for (final v in e) v / s];
  }

  static int _argmax(List<double> v) {
    var best = 0;
    for (var i = 1; i < v.length; i++) {
      if (v[i] > v[best]) best = i;
    }
    return best;
  }

  static TriageResult combine(List<double> photoProbs, Set<String> signIds) {
    final n = Disease.values.length;
    final chosen = [for (final id in signIds) if (signsById[id] != null) signsById[id]!];
    final clinical = chosen.where((s) => !_contextOnly.contains(s.id) && !s.exclusive).length;

    final signScore = List<double>.filled(n, 0);
    for (final s in chosen) {
      for (var i = 0; i < n; i++) {
        signScore[i] += s.w[i];
      }
    }
    final logits = [
      for (var i = 0; i < n; i++) photoWeight * math.log(math.max(photoProbs[i], 0.01)) + signScore[i],
    ];
    final probs = _softmax(logits);
    final top = _argmax(probs);
    final photoTop = _argmax(photoProbs);

    bool? agree;
    if (clinical > 0) {
      agree = _argmax(signScore) == photoTop;
    } else if (chosen.any((s) => s.exclusive)) {
      agree = photoTop == Disease.healthy.index;
    }

    final Reliability rel;
    if (chosen.isEmpty) {
      // Photo seule : jamais « forte ».
      rel = photoProbs[photoTop] >= 0.85 ? Reliability.medium : Reliability.low;
    } else if (probs[top] >= 0.80 && top == photoTop && agree == true) {
      // « Forte » seulement si de vrais signes confirment la photo (l'âge seul ne suffit pas).
      rel = Reliability.high;
    } else if (probs[top] >= 0.60) {
      rel = Reliability.medium;
    } else {
      rel = Reliability.low;
    }

    return TriageResult(
      disease: Disease.values[top],
      confidence: probs[top],
      probs: probs,
      reliability: rel,
      redFlag: chosen.any((s) => s.redFlag),
      clinicalSigns: clinical,
      signsAgree: agree,
    );
  }
}
