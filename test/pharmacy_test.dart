import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sifa/models/pharmacy.dart';
import 'package:sifa/services/pharmacy_directory.dart';

void main() {
  test('distance Douala centre -> Bonabéri : quelques km', () {
    final d = distanceKm(const LatLng(4.0511, 9.7679), const LatLng(4.0780, 9.6860));
    expect(d, inInclusiveRange(8, 10));
  });

  test('tri par distance : la plus proche en premier', () {
    final sorted = sortedByDistance(PharmacyDirectory.sample, PharmacyDirectory.centreDefaut);
    expect(sorted.first.id, 'p1');
    final d = [for (final p in sorted) distanceKm(PharmacyDirectory.centreDefaut, p.position)];
    expect(d, orderedEquals([...d]..sort()));
  });

  test('formatKm', () {
    expect(formatKm(0.45), '450 m');
    expect(formatKm(2.44), '2,4 km');
  });
}
