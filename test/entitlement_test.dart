import 'package:flutter_test/flutter_test.dart';
import 'package:sifa/data/pricing.dart';
import 'package:sifa/services/entitlement.dart';

void main() {
  final e = Entitlement.instance;
  const open = Pricing.defaults;
  final sold = Pricing(packs: open.packs, tiers: open.tiers, farmManagementAvailable: true);
  var clock = DateTime(2026, 11, 14);

  setUp(() {
    clock = DateTime(2026, 11, 14);
    e.now = () => clock;
    e.pricing = () => open;
    e.debugReset();
  });

  test('sans abonnement : 5 analyses gratuites, puis blocage', () {
    expect(e.limit, 5);
    expect(e.canAnalyze, isTrue);
    for (var i = 0; i < 4; i++) {
      e.recordAnalysis();
    }
    expect(e.remaining, 1);
    expect(e.canAnalyze, isTrue);
    e.recordAnalysis();
    expect(e.remaining, 0);
    expect(e.canAnalyze, isFalse);
    expect(e.isFree, isTrue);
  });

  test("le nombre d'analyses gratuites vient de la configuration", () {
    e.pricing = () => Pricing.fromRemote({'analyses_gratuites': 3});
    for (var i = 0; i < 3; i++) {
      e.recordAnalysis();
    }
    expect(e.canAnalyze, isFalse);
  });

  test('formule analyse : quota du pack, renouvelé tous les 30 jours', () {
    e.debugReset(offer: 'analyse_solo', since: DateTime(2026, 11, 1), until: DateTime(2027, 1, 1));
    expect(e.limit, 20);
    expect(e.isFree, isFalse);
    for (var i = 0; i < 20; i++) {
      e.recordAnalysis();
    }
    expect(e.canAnalyze, isFalse);
    clock = DateTime(2026, 12, 5); // 34 jours après l'activation : nouvelle période
    expect(e.used, 0);
    expect(e.canAnalyze, isTrue);
    e.recordAnalysis();
    expect(e.used, 1);
  });

  test('pack complet : le quota est celui de la formule analyse', () {
    e.debugReset(offer: 'pack_equipe_3', since: DateTime(2026, 11, 10), until: DateTime(2027, 1, 1));
    expect(e.limit, 60);
    expect(e.farmTier, 3);
  });

  test("formule gestion seule : les analyses restent sur l'essai gratuit", () {
    e.debugReset(offer: 'gestion_2', since: DateTime(2026, 11, 10), until: DateTime(2027, 1, 1));
    expect(e.isFree, isTrue);
    expect(e.limit, 5);
    expect(e.farmTier, 2);
  });

  test('anciennes formules : analyses illimitées', () {
    e.debugReset(offer: 'mensuelle', since: DateTime(2026, 11, 10), until: DateTime(2027, 1, 1));
    expect(e.limit, isNull);
    expect(e.canAnalyze, isTrue);
  });

  test('abonnement expiré : retour à la gratuité', () {
    e.debugReset(offer: 'analyse_pro', since: DateTime(2026, 9, 1), until: DateTime(2026, 11, 1));
    expect(e.offerId, isNull);
    expect(e.limit, 5);
  });

  test('gestion de ferme : libre tant que non mise en vente, puis réservée aux formules gestion et pack', () {
    expect(e.farmAccess, isTrue);
    e.pricing = () => sold;
    expect(e.farmAccess, isFalse);
    e.debugReset(offer: 'analyse_pro', since: DateTime(2026, 11, 1), until: DateTime(2027, 1, 1));
    expect(e.farmAccess, isFalse);
    e.debugReset(offer: 'gestion_1', since: DateTime(2026, 11, 1), until: DateTime(2027, 1, 1));
    expect(e.farmAccess, isTrue);
    e.debugReset(offer: 'pack_solo_1', since: DateTime(2026, 11, 1), until: DateTime(2027, 1, 1));
    expect(e.farmAccess, isTrue);
  });

  test('sérialisation aller-retour', () {
    e.debugReset(offer: 'analyse_solo', since: DateTime(2026, 11, 1), until: DateTime(2027, 1, 1), freeUsed: 2, paidUsed: 7);
    final j = e.toJson();
    e.debugReset();
    e.restore(j);
    expect(e.offerId, 'analyse_solo');
    expect(e.used, 7);
  });

  test("codes d'accès : analyse seule, gestion seule, les deux", () {
    e.pricing = () => sold;
    e.debugReset(offer: 'promo_analyse', since: DateTime(2026, 11, 1), until: DateTime(2027, 1, 1));
    expect(e.limit, isNull);
    expect(e.farmAccess, isFalse);
    e.debugReset(offer: 'promo_gestion', since: DateTime(2026, 11, 1), until: DateTime(2027, 1, 1));
    expect(e.limit, 5); // pas d'analyses en plus de l'essai
    expect(e.farmAccess, isTrue);
    expect(e.farmTier, isNull); // aucune limite de sujets
    e.debugReset(offer: 'promo_complet', since: DateTime(2026, 11, 1), until: DateTime(2027, 1, 1));
    expect(e.limit, isNull);
    expect(e.farmAccess, isTrue);
  });
}
