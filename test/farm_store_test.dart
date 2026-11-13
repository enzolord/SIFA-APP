import 'package:flutter_test/flutter_test.dart';
import 'package:sifa/services/farm_store.dart';
import 'package:sifa/services/session.dart';

void main() {
  test('mortalité, aliment et marge', () {
    final s = FarmStore.instance;
    s.addBand('A', FlockType.broiler, 500);
    final b = s.bands.last;
    s.addEntry(DailyEntry(bandId: b.id, date: DateTime.now(), dead: 5, feedKg: 40, avgWeightG: 300));
    expect(s.deadTotal(b), 5);
    expect(s.alive(b), 495);
    expect(s.mortalityPct(b), closeTo(1.0, 0.001));
    expect(s.feedToday, 40);
    s.addTxn(Txn(date: DateTime.now(), label: 'v', amount: 1000, isSale: true, category: 'Vente'));
    s.addTxn(Txn(date: DateTime.now(), label: 'd', amount: 400, isSale: false, category: 'Aliment'));
    expect(s.monthMargin, 600);
  });

  test('jours restants de stock', () {
    final it = StockItem(name: 'Maïs', qty: 120, unit: 'kg', dailyUse: 40);
    expect(it.daysLeft, 3);
  });

  test('format FCFA', () {
    expect(fcfa(1250000), '1 250 000');
    expect(fcfa(-412000), '-412 000');
  });

  test('sérialisation aller-retour de la ferme', () {
    final s = FarmStore.instance;
    s.addBand('Z', FlockType.layer, 300);
    final b = s.bands.last;
    s.addEntry(DailyEntry(bandId: b.id, date: DateTime(2026, 11, 9), dead: 2, feedKg: 10.5));
    s.addStock(StockItem(name: 'Maïs', qty: 80, unit: 'kg', dailyUse: 10));
    s.addTask('Nettoyer', DateTime(2026, 11, 10));
    final json = s.toJson();
    final before = (s.bands.length, s.entries.length, s.stock.length, s.tasks.length);
    s.restore(json);
    expect((s.bands.length, s.entries.length, s.stock.length, s.tasks.length), before);
    expect(s.alive(s.bands.last), 298);
  });

  test('taux de ponte, indice de consommation et aliment par oiseau', () {
    final s = FarmStore.instance;
    s.addBand('P', FlockType.layer, 100);
    final l = s.bands.last;
    s.addEntry(DailyEntry(bandId: l.id, date: DateTime.now(), dead: 0, feedKg: 11, eggs: 80));
    s.addEntry(DailyEntry(bandId: l.id, date: DateTime.now().subtract(const Duration(days: 1)), dead: 0, feedKg: 11, eggs: 90));
    expect(s.layingRate(l), closeTo(85, 0.01));
    expect(s.eggsToday(l), 80);
    expect(s.feedPerBirdG(l), closeTo(110, 0.01));

    s.addBand('C', FlockType.broiler, 200);
    final c = s.bands.last;
    expect(s.feedConversion(c), isNull);
    s.addEntry(DailyEntry(bandId: c.id, date: DateTime.now(), dead: 0, feedKg: 300, avgWeightG: 1000));
    expect(s.feedConversion(c), closeTo(1.5, 0.001));
  });

  test("journal de santé : délai d'attente et sérialisation", () {
    final s = FarmStore.instance;
    s.addBand('S', FlockType.broiler, 100);
    final b = s.bands.last;
    final h = HealthEvent(bandId: b.id, date: DateTime.now(), kind: HealthKind.treatment, product: 'Amoxicilline', withdrawalDays: 7);
    final old = HealthEvent(bandId: b.id, date: DateTime.now().subtract(const Duration(days: 30)), kind: HealthKind.treatment, product: 'Ancien', withdrawalDays: 7);
    s.addHealth(h);
    s.addHealth(old);
    expect(h.inWithdrawal, isTrue);
    expect(old.inWithdrawal, isFalse);
    expect(s.activeWithdrawals.contains(h), isTrue);
    final json = s.toJson();
    final n = s.health.length;
    s.restore(json);
    expect(s.health.length, n);
    expect(s.healthOf(s.bands.last).first.product, anyOf('Amoxicilline', 'Ancien'));
  });

  test('rentabilité par bande, prix des poussins et clients', () {
    final s = FarmStore.instance;
    final b = s.addBand('R', FlockType.broiler, 100, chickCost: 50000);
    expect(s.expensesOf(b), 50000);
    s.addTxn(Txn(date: DateTime.now(), label: 'Vente', amount: 120000, isSale: true, category: 'Vente', bandId: b.id, client: 'Mme Ngo'));
    s.addTxn(Txn(date: DateTime.now(), label: 'Aliment', amount: 30000, isSale: false, category: 'Aliment', bandId: b.id));
    s.addTxn(Txn(date: DateTime.now(), label: 'Vente libre', amount: 999, isSale: true, category: 'Vente'));
    expect(s.salesOf(b), 120000);
    expect(s.expensesOf(b), 80000);
    expect(s.profitOf(b), 40000);
    expect(s.profitPerBird(b), closeTo(400, 0.001));
    expect(s.unassignedSales, greaterThanOrEqualTo(999));
    s.addClient(Client(name: 'Mme Ngo', phone: '690000000'));
    s.addClient(Client(name: 'mme ngo')); // doublon ignoré
    expect(s.clients.where((c) => c.name.toLowerCase() == 'mme ngo').length, 1);
    expect(s.totalBoughtBy('MME NGO'), 120000);
    final json = s.toJson();
    s.restore(json);
    expect(s.profitOf(s.bands.firstWhere((x) => x.name == 'R')), 40000);
  });
}
