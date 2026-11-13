import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sifa/data/knowledge.dart';
import 'package:sifa/l10n/strings_en.dart';
import 'package:sifa/models/diagnosis.dart';
import 'package:sifa/services/classifier.dart';
import 'package:sifa/services/triage.dart';

/// Probabilités photo dans l'ordre de Disease.values : sain, coccidiose, salmonellose, Newcastle.
List<double> photo({double h = 0.02, double c = 0.02, double s = 0.02, double n = 0.02}) => [h, c, s, n];

void main() {
  group('Triage : photo + signes', () {
    test('photo seule : jamais une fiabilité forte', () {
      final r = Triage.combine(photo(c: 0.94), {});
      expect(r.disease, Disease.coccidiosis);
      expect(r.reliability, Reliability.medium);
      expect(r.signsAgree, isNull);
      expect(Triage.combine(photo(c: 0.60, h: 0.36), {}).reliability, Reliability.low);
    });

    test('signes concordants : fiabilité forte', () {
      final r = Triage.combine(photo(c: 0.90, h: 0.06), {'blood', 'age_young', 'huddle'});
      expect(r.disease, Disease.coccidiosis);
      expect(r.reliability, Reliability.high);
      expect(r.signsAgree, isTrue);
      expect(r.redFlag, isFalse);
    });

    test('un objet vert pris pour Newcastle est corrigé quand les oiseaux vont bien', () {
      final r = Triage.combine(photo(n: 0.90, h: 0.06), {'none'});
      expect(r.disease, isNot(Disease.newcastle));
      expect(r.signsAgree, isFalse);
      expect(r.reliability, isNot(Reliability.high));
    });

    test('les signes peuvent contredire la photo', () {
      // Photo « saine », mais sang dans les fientes chez des jeunes en boule.
      final r = Triage.combine(photo(h: 0.80, c: 0.15), {'blood', 'age_young', 'huddle', 'anorexia'});
      expect(r.disease, Disease.coccidiosis);
      expect(r.signsAgree, isFalse);
      expect(r.reliability, isNot(Reliability.high));
    });

    test('signes nerveux ou mortalité brutale : alerte, quel que soit le résultat photo', () {
      expect(Triage.combine(photo(h: 0.95), {'nervous'}).redFlag, isTrue);
      expect(Triage.combine(photo(s: 0.95), {'death_fast'}).redFlag, isTrue);
      final r = Triage.combine(photo(h: 0.70, n: 0.20), {'nervous', 'resp', 'death_fast'});
      expect(r.disease, Disease.newcastle);
    });

    test('poussins à diarrhée blanche : salmonellose', () {
      final r = Triage.combine(photo(s: 0.70, h: 0.25), {'age_chick', 'white_vent', 'death_chicks'});
      expect(r.disease, Disease.salmonella);
      expect(r.reliability, Reliability.high);
    });

    test('âge seul : pas d\'avis sur la concordance', () {
      final r = Triage.combine(photo(c: 0.9), {'age_young'});
      expect(r.signsAgree, isNull);
      expect(r.reliability, Reliability.medium);
    });

    test('les probabilités finales font 1 et chaque signe a 4 poids', () {
      final r = Triage.combine(photo(c: 0.5, s: 0.3, n: 0.1, h: 0.1), {'green', 'resp'});
      expect(r.probs.reduce((a, b) => a + b), closeTo(1, 1e-9));
      for (final s in signsById.values) {
        expect(s.w.length, Disease.values.length, reason: s.id);
      }
    });
  });

  group('Classifieur : lecture des sorties du modèle', () {
    const four = [Disease.coccidiosis, Disease.healthy, Disease.newcastle, Disease.salmonella];
    const five = [null, Disease.coccidiosis, Disease.healthy, Disease.newcastle, Disease.salmonella];

    test('étiquettes du modèle', () {
      expect(TfliteClassifier.diseaseForLabel('Coccidiosis'), Disease.coccidiosis);
      expect(TfliteClassifier.diseaseForLabel('Healthy'), Disease.healthy);
      expect(TfliteClassifier.diseaseForLabel('New_Castle_Disease'), Disease.newcastle);
      expect(TfliteClassifier.diseaseForLabel('Salmonella'), Disease.salmonella);
      expect(TfliteClassifier.diseaseForLabel('Autre'), isNull);
    });

    test('modèle à 4 classes : résultat remis dans l\'ordre de Disease.values', () {
      final o = TfliteClassifier.interpret([0.05, 0.05, 0.85, 0.05], four, viewsAgree: true);
      expect(o.ok, isTrue);
      expect(o.probs![Disease.newcastle.index], closeTo(0.85, 1e-9));
    });

    test('modèle hésitant ou vues en désaccord : photo refusée', () {
      expect(TfliteClassifier.interpret([0.4, 0.3, 0.2, 0.1], four, viewsAgree: true).issue, ScanIssue.unclear);
      expect(TfliteClassifier.interpret([0.7, 0.2, 0.05, 0.05], four, viewsAgree: false).issue, ScanIssue.unclear);
      expect(TfliteClassifier.interpret([0.9, 0.05, 0.03, 0.02], four, viewsAgree: false).ok, isTrue);
    });

    test('modèle à 5 classes : la classe « Autre » refuse la photo', () {
      expect(TfliteClassifier.interpret([0.8, 0.05, 0.05, 0.05, 0.05], five, viewsAgree: true).issue,
          ScanIssue.notDropping);
      final o = TfliteClassifier.interpret([0.1, 0.72, 0.06, 0.06, 0.06], five, viewsAgree: true);
      expect(o.ok, isTrue);
      expect(o.probs![Disease.coccidiosis.index], closeTo(0.8, 1e-9));
    });

    test('photo noire ou surface unie : refusée avant le modèle', () {
      Uint8List solid(int r, int g, int b) {
        final px = Uint8List(64 * 64 * 4);
        for (var i = 0; i < px.length; i += 4) {
          px[i] = r;
          px[i + 1] = g;
          px[i + 2] = b;
          px[i + 3] = 255;
        }
        return px;
      }

      expect(TfliteClassifier.checkQuality(solid(5, 5, 5)), ScanIssue.tooDark);
      expect(TfliteClassifier.checkQuality(solid(40, 160, 60)), ScanIssue.tooPlain); // objet vert uni
      final textured = solid(120, 90, 60);
      for (var i = 0; i < textured.length; i += 8) {
        textured[i] = 220;
        textured[i + 1] = 200;
      }
      expect(TfliteClassifier.checkQuality(textured), isNull);
    });
  });

  group('Fiches maladies', () {
    test('chaque maladie a une fiche complète', () {
      for (final d in Disease.values) {
        final s = diseaseSheets[d];
        expect(s, isNotNull, reason: '$d');
        expect(s!.recognize, isNotEmpty);
        expect(s.now, isNotEmpty);
        expect(s.scientific, isNotEmpty);
        expect(s.artisanal, isNotEmpty);
        expect(s.prevention, isNotEmpty);
        // Chaque remède artisanal porte son niveau de preuve.
        for (final a in s.artisanal) {
          expect(a.evidence, isNotNull, reason: a.title);
        }
      }
    });

    test('tout est traduit en anglais', () {
      final texts = <String>[
        kbPendingValidation,
        ...evidenceLabel.values,
        for (final i in diseaseInfo.values) ...[i.name, i.shortName],
        for (final g in signGroups) ...[g.title, for (final s in g.signs) s.label],
        for (final s in diseaseSheets.values) ...[
          for (final i in [...s.recognize, ...s.scientific, ...s.artisanal]) ...[i.title, i.body],
          ...s.now,
          ...s.prevention,
          ...s.confusions,
          if (s.humanRisk != null) s.humanRisk!,
        ],
      ];
      for (final t in texts) {
        expect(enStrings.containsKey(t), isTrue, reason: 'Sans traduction : $t');
      }
    });
  });
}
