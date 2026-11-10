import 'package:latlong2/latlong.dart';

import '../widgets/status_chip.dart';

/// Une pharmacie / un point de vente vétérinaire géolocalisé.
class Pharmacy {
  const Pharmacy({
    required this.id,
    required this.name,
    required this.area,
    required this.position,
    this.phone,
    this.hours = 'Horaires non renseignés',
    this.stock = SifaStatus.neutral,
    this.stockLabel = 'Stock non renseigné',
  });

  final String id;
  final String name;
  final String area; // quartier / ville
  final LatLng position;
  final String? phone;
  final String hours;
  final SifaStatus stock;
  final String stockLabel;
}

const _distance = Distance();

/// Distance à vol d'oiseau en kilomètres.
double distanceKm(LatLng a, LatLng b) => _distance.as(LengthUnit.Kilometer, a, b);

/// Copie triée de la plus proche à la plus éloignée de [from].
List<Pharmacy> sortedByDistance(Iterable<Pharmacy> items, LatLng from) {
  final list = items.toList();
  list.sort((a, b) => distanceKm(from, a.position).compareTo(distanceKm(from, b.position)));
  return list;
}

String formatKm(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
