import 'package:flutter_test/flutter_test.dart';
import 'package:sifa/screens/ferme/report_screen.dart';
import 'package:sifa/services/farm_store.dart';
import 'package:sifa/services/session.dart';

void main() {
  test('le rapport de bande résume effectif, mortalité, résultats et délais', () {
    final s = FarmStore.instance;
    final b = s.addBand('Rapport', FlockType.broiler, 200, chickCost: 100000);
    s.addEntry(DailyEntry(bandId: b.id, date: DateTime.now(), dead: 4, feedKg: 100, avgWeightG: 1000));
    s.addHealth(HealthEvent(bandId: b.id, date: DateTime.now(), kind: HealthKind.treatment, product: 'Amoxicilline', withdrawalDays: 5));
    final r = bandReport(b);
    expect(r, contains('Rapport'));
    expect(r, contains('196 vivants sur 200'));
    expect(r, contains('Mortalité : 2'));
    expect(r, contains('Indice de consommation'));
    expect(r, contains('Amoxicilline'));
    expect(r, contains('Ne pas vendre avant le'));
    expect(r.length, lessThan(600)); // reste lisible dans un code QR
  });
}
