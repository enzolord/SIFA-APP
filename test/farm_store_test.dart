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
}
