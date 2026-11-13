import 'package:flutter_test/flutter_test.dart';
import 'package:sifa/data/pricing.dart';

void main() {
  const p = Pricing.defaults;

  test('grille analyse : prix par analyse', () {
    expect([for (final a in p.packs) a.pricePerAnalysis], [100, 75, 60, 50]);
    expect([for (final a in p.packs) a.price], [2000, 4500, 12000, 30000]);
    expect([for (final a in p.packs) a.accounts], [1, 3, 10, 25]);
    expect([for (final a in p.packs) a.analyses], [20, 60, 200, 600]);
  });

  test('grille gestion : sept paliers, le dernier sur devis', () {
    expect(p.tiers.length, 7);
    expect([for (final t in p.tiers) t.price], [5000, 6000, 8000, 11000, 15000, 22000, null]);
    expect(p.tier(7).onQuote, isTrue);
    expect(p.tier(1).min, 200);
    expect(p.tier(7).max, isNull);
  });

  test('pack complet : les cinq combinaisons de la grille officielle', () {
    final expected = {
      ('solo', 1): (7000, 5950, 1050),
      ('solo', 2): (8000, 6800, 1200),
      ('equipe', 3): (12500, 10650, 1850),
      ('pro', 4): (23000, 19550, 3450),
      ('entreprise', 6): (52000, 44200, 7800),
    };
    for (final e in expected.entries) {
      final d = p.deal(p.packByKey(e.key.$1), p.tier(e.key.$2))!;
      expect((d.sum, d.price, d.saving), e.value, reason: '${e.key}');
    }
    expect(Pricing.featured.length, 5);
  });

  test('pack complet : impossible avec un palier sur devis', () {
    expect(p.deal(p.packByKey('solo'), p.tier(7)), isNull);
  });

  test('corrections de l\'administration', () {
    final r = Pricing.fromRemote({
      'prix': {'analyse_solo': 2500, 'gestion_7': 40000, 'gestion_2': -5, 'analyse_pro': 'abc'},
      'reduction_pack': 20,
      'gestion_disponible': true,
    });
    expect(r.packByKey('solo').price, 2500);
    expect(r.packByKey('pro').price, 12000); // invalide : défaut conservé
    expect(r.tier(2).price, 6000);
    expect(r.tier(7).price, 40000);
    expect(r.packDiscount, 20);
    expect(r.farmManagementAvailable, isTrue);
    expect(Pricing.fromRemote({}).farmManagementAvailable, isFalse);
    expect(Pricing.fromRemote({}).tier(7).price, isNull);
  });

  test('identifiants d\'offre', () {
    expect(p.lookup('analyse_equipe'), ('Analyse ÉQUIPE', 4500));
    expect(p.lookup('gestion_3'), ('Gestion 3', 8000));
    expect(p.lookup('pack_solo_1'), ('Pack SOLO + Gestion 1', 5950));
    expect(p.lookup('mensuelle'), isNull);
  });

  test('format FCFA', () {
    expect(fcfa(500), '500 FCFA');
    expect(fcfa(2000), '2 000 FCFA');
    expect(fcfa(44200), '44 200 FCFA');
  });
}
