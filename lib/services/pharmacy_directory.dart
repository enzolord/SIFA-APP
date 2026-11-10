import 'package:latlong2/latlong.dart';

import '../models/pharmacy.dart';
import '../widgets/status_chip.dart';

/// Annuaire des pharmacies vétérinaires.
///
/// DONNÉES D'EXEMPLE (zone de Douala) : les noms, positions, horaires et stocks
/// sont indicatifs. L'annuaire réel (table `pharmacies`, avec stock mis à jour
/// par les pharmacies) arrivera avec la synchronisation Supabase.
class PharmacyDirectory {
  static const centreDefaut = LatLng(4.0511, 9.7679); // Douala

  static const sample = <Pharmacy>[
    Pharmacy(
      id: 'p1',
      name: 'Pharmacie vétérinaire du Centre',
      area: 'Akwa',
      position: LatLng(4.0511, 9.7679),
      phone: '+237600000001',
      hours: "Ouverte jusqu'à 18:00",
      stock: SifaStatus.ok,
      stockLabel: 'En stock',
    ),
    Pharmacy(
      id: 'p2',
      name: 'Agro-Vet Bonabéri',
      area: 'Bonabéri',
      position: LatLng(4.0780, 9.6860),
      phone: '+237600000002',
      hours: "Ouverte jusqu'à 17:30",
      stock: SifaStatus.warn,
      stockLabel: 'Stock limité',
    ),
    Pharmacy(
      id: 'p3',
      name: 'Élevage Plus Logbessou',
      area: 'Logbessou',
      position: LatLng(4.0900, 9.7940),
      phone: '+237600000003',
      hours: 'Fermée, ouvre à 08:00',
      stock: SifaStatus.danger,
      stockLabel: 'Rupture',
    ),
  ];
}
