import 'package:flutter_test/flutter_test.dart';
import 'package:sifa/data/knowledge.dart';
import 'package:sifa/models/diagnosis.dart';
import 'package:sifa/services/remote_content.dart';
import 'package:sifa/widgets/status_chip.dart';

void main() {
  group('Contenu distant', () {
    test('texte bilingue : langue demandée, repli sur le français', () {
      final v = {'fr': 'Bonjour', 'en': 'Hello'};
      expect(localized(v, lang: 'en'), 'Hello');
      expect(localized(v, lang: 'fr'), 'Bonjour');
      expect(localized({'fr': 'Seulement'}, lang: 'en'), 'Seulement');
      expect(localized({'fr': 'A', 'en': '  '}, lang: 'en'), 'A');
      expect(localized('simple'), 'simple');
      expect(localized(null), '');
    });

    test('annonce et maintenance : seulement si activées et non vides', () {
      final rc = RemoteContent.instance;
      rc.applyJson({
        'contenu': {
          'annonce': {'actif': true, 'niveau': 'warn', 'titre': {'fr': 'Alerte'}, 'texte': {'fr': 'Newcastle à Douala'}},
          'maintenance': {'actif': false},
        },
      });
      expect(rc.announcement?.level, 'warn');
      expect(rc.announcement?.title, 'Alerte');
      expect(rc.maintenanceMessage, isNull);

      rc.applyJson({
        'contenu': {
          'annonce': {'actif': true, 'titre': {'fr': ''}, 'texte': {'fr': ''}},
          'maintenance': {'actif': true, 'message': {'fr': 'Retour à 18 h'}},
        },
      });
      expect(rc.announcement, isNull);
      expect(rc.maintenanceMessage, 'Retour à 18 h');
    });

    test('pharmacie : ligne de la base convertie, lignes incomplètes ignorées', () {
      final p = RemoteContent.parsePharmacy({
        'id': 'abc',
        'nom': 'Agro-Vet',
        'ville': 'Douala',
        'quartier': '',
        'telephone': ' +237600000009 ',
        'horaires': '',
        'latitude': 4.05,
        'longitude': 9.76,
        'stock': 'rupture',
      });
      expect(p, isNotNull);
      expect(p!.area, 'Douala');
      expect(p.phone, '+237600000009');
      expect(p.stock, SifaStatus.danger);
      expect(p.hours, 'Horaires non renseignés');
      expect(RemoteContent.parsePharmacy({'nom': 'Sans position'}), isNull);
      expect(RemoteContent.parsePharmacy({'id': 1, 'nom': 'X', 'latitude': 99, 'longitude': 0}), isNull);
    });

    test('liste de pharmacies vide mais reçue : on n\'affiche pas l\'exemple intégré', () {
      final rc = RemoteContent.instance;
      rc.applyJson({'contenu': {}, 'pharmacies': []});
      expect(rc.pharmacies, isEmpty);
    });

    test('fiche : une liste fournie remplace, une liste vide laisse la fiche intégrée', () {
      final base = diseaseSheets[Disease.coccidiosis]!;
      final out = applySheetOverride(base, {
        'maintenant': [
          {'fr': 'Isolez les malades', 'en': 'Isolate sick birds'},
          {'fr': '  '},
        ],
        'prevention': [],
        'artisanal': [
          {'titre': {'fr': 'Aloe vera'}, 'texte': {'fr': 'Dans l\'eau'}, 'preuve': 'limited'},
          {'titre': {'fr': ''}, 'texte': {'fr': ''}},
        ],
        'risque_humain': {'fr': 'Aucun'},
      });
      expect(out.now, ['Isolez les malades']);
      expect(out.prevention, base.prevention);
      expect(out.artisanal.length, 1);
      expect(out.artisanal.first.evidence, Evidence.limited);
      expect(out.scientific.length, base.scientific.length);
      expect(out.humanRisk, 'Aucun');
      expect(applySheetOverride(base, const {}).now, base.now);
    });
  });
}
