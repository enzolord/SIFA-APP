import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  const RouteResult({required this.points, required this.km, required this.duration});
  final List<LatLng> points;
  final double km;
  final Duration duration;
}

/// Itinéraire routier via le serveur OSRM public (gratuit, sans clé).
/// Le serveur de démonstration convient aux tests ; pour la production,
/// héberger OSRM ou passer à un service avec clé (OpenRouteService, etc.).
/// Retourne null si le réseau ou le service est indisponible.
Future<RouteResult?> fetchRoute(LatLng from, LatLng to) async {
  final uri = Uri.parse(
    'https://router.project-osrm.org/route/v1/driving/'
    '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
    '?overview=full&geometries=geojson',
  );
  try {
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = json['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return null;
    final route = routes.first as Map<String, dynamic>;
    final coords = (route['geometry'] as Map<String, dynamic>)['coordinates'] as List<dynamic>;
    final points = [
      for (final c in coords)
        LatLng(((c as List<dynamic>)[1] as num).toDouble(), (c[0] as num).toDouble()),
    ];
    return RouteResult(
      points: points,
      km: (route['distance'] as num).toDouble() / 1000,
      duration: Duration(seconds: (route['duration'] as num).round()),
    );
  } catch (_) {
    return null;
  }
}
