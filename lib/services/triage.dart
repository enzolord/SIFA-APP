import 'dart:math' as math;

import '../models/diagnosis.dart';

/// Signe clinique observé (ou non) dans la bande.
///
/// [w] : poids ajouté au score de chaque maladie quand le signe est présent
/// (positif = le signe va dans le sens de la maladie, négatif = il la rend moins probable).
/// Ces poids traduisent les manuels vétérinaires (MSD, OMSA, FAO, ACIAR) en une règle
/// simple. Ce ne sont pas des valeurs mesurées : À VALIDER PAR LE VÉTÉRINAIRE RÉFÉRENT.
class Sign {
  const Sign(this.id, this.w, {this.redFlag = false});
  final String id;

  /// Ordre : sain, coccidiose, salmonellose, Newcastle (= Disease.values).
  final List<double> w;

  /// Signe d'alerte : maladie contagieuse grave possible, quel que soit le résultat photo.
  final bool redFlag;
}

//                              sain  cocci salmo  ND
const _signs = <Sign>[
  Sign('age_chick', [0, -0.6, 1.0, 0]),
  Sign('age_young', [0, 0.8, -0.2, 0]),
  Sign('age_adult', [0, -0.5, 0.3, 0]),
  Sign('blood', [-2.0, 2.0, -0.5, -0.5]),
  Sign('white_vent', [-1.5, -0.3, 1.5, 0.2]),
  Sign('green', [-1.5, -0.3, 0.4, 1.0]),
  Sign('yellow', [-1.5, 0, 1.0, 0]),
  Sign('huddle', [-1.5, 0.3, 0.3, 0.3]),
  Sign('thirst', [-0.5, 0.4, 0, 0]),
  Sign('resp', [-1.5, -0.7, 0.2, 1.5]),
  Sign('nervous', [-2.5, -1.0, -1.0, 2.5], redFlag: true),
  Sign('head', [-1.5, -0.5, 0, 1.0]),
  Sign('eggs', [-1.0, 0, 0.3, 1.2]),
  Sign('death_some', [-1.0, 0.3, 0.3, 0.3]),
  Sign('death_fast', [-3.0, 0.2, 0.5, 1.5], redFlag: true),
  Sign('death_chicks', [-2.0, 0.3, 1.2, 0]),
  Sign('vacc_nd', [0, 0, 0, -1.2]),
];

final Map<String, Sign> signsById = {for (final s in _signs) s.id: s};

/// Préfixe d'un signe que l'éleveur a déclaré ABSENT (« Non » à la question).
const noPrefix = 'no:';

/// Un « Non » compte moins qu'un « Oui » : ne pas voir un signe ne l'exclut pas.
const noWeight = 0.35;

/// Signes de contexte : ils orientent, mais ne disent rien de l'état des poulets.
const _contextOnly = {'age_chick', 'age_young', 'age_adult', 'vacc_nd'};

// ───────────────────────── Questions adaptatives ─────────────────────────

class Option {
  const Option(this.label, this.signs);
  final String label;

  /// Signes ajoutés si l'éleveur choisit cette réponse (ids, ou `no:id` pour un signe absent).
  final List<String> signs;
}

class Question {
  const Question(this.id, this.text, this.options, {this.help});
  final String id;
  final String text;
  final String? help;
  final List<Option> options;
}

const _yes = 'Oui';
const _no = 'Non';
const _unknown = 'Je ne sais pas';

Question _yesNo(String id, String text, String sign, {String? help}) => Question(id, text, [
      Option(_yes, [sign]),
      Option(_no, ['$noPrefix$sign']),
      const Option(_unknown, []),
    ], help: help);

final Map<String, Question> questionsById = {
  for (final q in [
    const Question('age', 'Quel âge ont les poulets ?', [
      Option('Poussins de moins de 3 semaines', ['age_chick']),
      Option('Jeunes de 3 à 8 semaines', ['age_young']),
      Option('Adultes ou pondeuses', ['age_adult']),
      Option(_unknown, []),
    ]),
    _yesNo('blood', 'Voyez-vous du sang dans les fientes ?', 'blood'),
    const Question('diarrhea', 'Les fientes sont-elles liquides ?', [
      Option('Oui, vertes', ['green']),
      Option('Oui, jaunes', ['yellow']),
      Option('Oui, blanches et collées au cloaque', ['white_vent']),
      Option('Oui, d\'une autre couleur', []),
      Option(_no, ['no:green', 'no:yellow', 'no:white_vent']),
      Option(_unknown, []),
    ]),
    _yesNo('huddle', 'Des poulets restent-ils en boule, plumes ébouriffées, sans manger ?', 'huddle'),
    _yesNo('thirst', 'Boivent-ils plus que d\'habitude ?', 'thirst'),
    _yesNo('resp', 'Des poulets toussent-ils, éternuent-ils ou respirent-ils avec difficulté ?', 'resp'),
    _yesNo('nervous', 'Certains ont-ils le cou tordu, des tremblements ou une paralysie ?', 'nervous'),
    _yesNo('head', 'Certains ont-ils la tête ou les yeux gonflés ?', 'head'),
    _yesNo('eggs', 'La ponte a-t-elle chuté, ou les œufs sont-ils déformés ou à coquille molle ?', 'eggs'),
    const Question('deaths', 'Y a-t-il eu des morts ces derniers jours ?', [
      Option('Non, aucun', ['no:death_some', 'no:death_fast']),
      Option('Oui, quelques-uns', ['death_some']),
      Option('Oui, beaucoup en 1 à 3 jours', ['death_fast']),
      Option(_unknown, []),
    ]),
    _yesNo('death_chicks', 'Les morts sont-ils surtout des poussins ?', 'death_chicks'),
    const Question('vacc', 'Les poulets ont-ils été vaccinés contre la maladie de Newcastle ?', [
      Option('Oui, il y a moins de 4 mois', ['vacc_nd']),
      Option('Non, ou il y a plus de 4 mois', []),
      Option(_unknown, []),
    ]),
  ])
    q.id: q,
};

/// Choisit la prochaine question selon la photo et les réponses déjà données.
class Questionnaire {
  /// Renvoie null quand il n'y a plus rien d'utile à demander.
  ///
  /// [answers] : id de question -> index de la réponse choisie.
  static Question? next(List<double> photoProbs, Map<String, int> answers) {
    final signs = signsOf(answers);
    final photo = Disease.values[Triage.argmax(photoProbs)];
    bool has(String s) => signs.contains(s);

    final order = <String>[
      'age',
      // La question la plus utile pour ce que la photo suggère passe en premier.
      ...switch (photo) {
        Disease.coccidiosis => ['blood', 'huddle'],
        Disease.salmonella => ['diarrhea', 'deaths'],
        Disease.newcastle => ['resp', 'nervous', 'deaths'],
        Disease.healthy => ['huddle', 'diarrhea'],
      },
      'blood', 'diarrhea', 'huddle', 'resp', 'nervous', 'deaths',
      'thirst', 'head', 'eggs', 'death_chicks', 'vacc',
    ];

    bool applies(String id) => switch (id) {
          // Soif : utile seulement si la coccidiose est en jeu.
          'thirst' => photo == Disease.coccidiosis || has('blood'),
          // Tête gonflée : seulement si des signes respiratoires ou nerveux existent.
          'head' => has('resp') || has('nervous'),
          // Ponte : pas de question pour des poussins ou des jeunes.
          'eggs' => has('age_adult'),
          // Morts de poussins : seulement s'il y a des morts et que la bande peut en contenir.
          'death_chicks' => (has('death_some') || has('death_fast')) && !has('age_adult') && !has('age_young'),
          // Vaccin : seulement si Newcastle est une hypothèse.
          'vacc' => photo == Disease.newcastle ||
              has('resp') ||
              has('nervous') ||
              has('green') ||
              has('death_fast') ||
              has('eggs'),
          _ => true,
        };

    for (final id in order) {
      if (!answers.containsKey(id) && applies(id)) return questionsById[id];
    }
    return null;
  }

  /// Signes (présents ou absents) correspondant aux réponses données.
  static Set<String> signsOf(Map<String, int> answers) => {
        for (final e in answers.entries)
          if (questionsById[e.key] != null && e.value >= 0 && e.value < questionsById[e.key]!.options.length)
            ...questionsById[e.key]!.options[e.value].signs,
      };
}

// ───────────────────────── Combinaison photo + signes ─────────────────────────

class TriageResult {
  const TriageResult({
    required this.disease,
    required this.confidence,
    required this.probs,
    required this.reliability,
    required this.redFlag,
    required this.answered,
    required this.signsAgree,
  });

  final Disease disease;
  final double confidence;

  /// Probabilités finales, dans l'ordre de [Disease.values].
  final List<double> probs;
  final Reliability reliability;
  final bool redFlag;

  /// Nombre de signes cliniques renseignés, présents ou absents (hors âge et vaccin).
  final int answered;

  /// null : aucun signe clinique renseigné ; true : les réponses pointent vers la même
  /// conclusion que la photo ; false : elles pointent ailleurs.
  final bool? signsAgree;
}

class Triage {
  /// Poids donné à la photo. Inférieur à 1 : l'image seule est fragile (éclairage,
  /// cadrage), les signes doivent pouvoir la corriger.
  static const photoWeight = 0.7;

  static List<double> _softmax(List<double> logits) {
    final m = logits.reduce(math.max);
    final e = [for (final l in logits) math.exp(l - m)];
    final s = e.reduce((a, b) => a + b);
    return [for (final v in e) v / s];
  }

  static int argmax(List<double> v) {
    var best = 0;
    for (var i = 1; i < v.length; i++) {
      if (v[i] > v[best]) best = i;
    }
    return best;
  }

  /// [signIds] : signes présents (`blood`) et signes déclarés absents (`no:blood`).
  static TriageResult combine(List<double> photoProbs, Set<String> signIds) {
    final n = Disease.values.length;
    final signScore = List<double>.filled(n, 0);
    var answered = 0;
    var redFlag = false;
    var any = false;
    for (final raw in signIds) {
      final absent = raw.startsWith(noPrefix);
      final s = signsById[absent ? raw.substring(noPrefix.length) : raw];
      if (s == null) continue;
      any = true;
      if (!_contextOnly.contains(s.id)) answered++;
      if (!absent && s.redFlag) redFlag = true;
      final k = absent ? -noWeight : 1.0;
      for (var i = 0; i < n; i++) {
        signScore[i] += k * s.w[i];
      }
    }

    final logits = [
      for (var i = 0; i < n; i++) photoWeight * math.log(math.max(photoProbs[i], 0.01)) + signScore[i],
    ];
    final probs = _softmax(logits);
    final top = argmax(probs);
    final photoTop = argmax(photoProbs);
    final bool? agree = answered > 0 ? argmax(signScore) == photoTop : null;

    final Reliability rel;
    if (!any) {
      // Photo seule : jamais « forte ».
      rel = photoProbs[photoTop] >= 0.85 ? Reliability.medium : Reliability.low;
    } else if (probs[top] >= 0.80 && top == photoTop && agree == true && answered >= 3) {
      // « Forte » seulement si au moins trois réponses confirment la photo.
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
      redFlag: redFlag,
      answered: answered,
      signsAgree: agree,
    );
  }
}
