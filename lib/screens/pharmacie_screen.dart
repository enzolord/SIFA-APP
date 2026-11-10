import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pharmacy.dart';
import '../services/locator.dart';
import '../services/pharmacy_directory.dart';
import '../services/routing.dart';
import '../theme/colors.dart';
import '../widgets/status_chip.dart';
import '../l10n/l10n.dart';

/// Carte interactive des pharmacies vétérinaires, avec itinéraire.
class PharmacieScreen extends StatefulWidget {
  const PharmacieScreen({super.key});

  @override
  State<PharmacieScreen> createState() => _PharmacieScreenState();
}

class _PharmacieScreenState extends State<PharmacieScreen> {
  final _map = MapController();
  final _items = PharmacyDirectory.sample;

  LatLng? _me;
  bool _locating = true;
  Pharmacy? _selected;
  RouteResult? _route;
  bool _routing = false;
  String? _notice;

  LatLng get _origin => _me ?? PharmacyDirectory.centreDefaut;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final pos = await currentPosition();
    if (!mounted) return;
    setState(() {
      _me = pos;
      _locating = false;
      _notice = pos == null
          ? 'Position indisponible : activez la localisation pour voir les distances et les itinéraires.'
          : null;
    });
    _fitAll();
  }

  void _fitAll() {
    final pts = [..._items.map((p) => p.position), if (_me != null) _me!];
    try {
      _map.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: const EdgeInsets.all(56),
        maxZoom: 15,
      ));
    } catch (_) {/* carte pas encore prête */}
  }

  void _select(Pharmacy p) {
    setState(() {
      _selected = p;
      _route = null;
    });
    try {
      _map.move(p.position, 14);
    } catch (_) {}
  }

  Future<void> _showRoute(Pharmacy p) async {
    if (_me == null) {
      setState(() => _notice = "Pour tracer l'itinéraire, activez la localisation puis touchez la cible en haut.");
      return;
    }
    setState(() {
      _routing = true;
      _notice = null;
    });
    final r = await fetchRoute(_me!, p.position);
    if (!mounted) return;
    setState(() {
      _routing = false;
      _route = r;
      if (r == null) {
        _notice = "Itinéraire indisponible (réseau ?). Utilisez « Ouvrir dans Maps ».";
      }
    });
    if (r != null) {
      try {
        _map.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(r.points),
          padding: const EdgeInsets.all(48),
        ));
      } catch (_) {}
    }
  }

  Future<void> _openMaps(Pharmacy p) async {
    final dest = '${p.position.latitude},${p.position.longitude}';
    final origin = _me == null ? '' : '&origin=${_me!.latitude},${_me!.longitude}';
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$dest$origin&travelmode=driving');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) setState(() => _notice = "Impossible d'ouvrir l'application de cartes.");
  }

  Future<void> _call(Pharmacy p) async {
    if (p.phone == null) return;
    await launchUrl(Uri(scheme: 'tel', path: p.phone));
  }

  Color _pinColor(SifaStatus s) => switch (s) {
        SifaStatus.ok => SifaColors.ok,
        SifaStatus.warn => SifaColors.warn,
        SifaStatus.danger => SifaColors.danger,
        SifaStatus.neutral => SifaColors.inkMuted,
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sorted = sortedByDistance(_items, _origin);
    return Scaffold(
      appBar: AppBar(
        title: const Tx('Pharmacies vétérinaires'),
        actions: [
          IconButton(
            tooltip: tr('Ma position'),
            onPressed: _locating ? null : _locate,
            icon: _locating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          flex: 5,
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: PharmacyDirectory.centreDefaut,
              initialZoom: 11.5,
              minZoom: 5,
              maxZoom: 18,
              onMapReady: _fitAll,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.invlab.sifa',
              ),
              if (_route != null)
                PolylineLayer(polylines: [
                  Polyline(points: _route!.points, strokeWidth: 6, color: SifaColors.brand),
                ]),
              MarkerLayer(markers: [
                for (final p in _items)
                  Marker(
                    point: p.position,
                    width: 48,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _select(p),
                      child: Icon(
                        Icons.location_on,
                        size: _selected?.id == p.id ? 48 : 40,
                        color: _pinColor(p.stock),
                      ),
                    ),
                  ),
                if (_me != null)
                  Marker(
                    point: _me!,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A73E8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
                      ),
                    ),
                  ),
              ]),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('© contributeurs OpenStreetMap')],
              ),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Tx(_notice!, style: t.bodyMedium?.copyWith(color: SifaColors.warn)),
                ),
              for (final p in sorted) ...[
                _card(context, p),
                const SizedBox(height: 10),
              ],
              Tx(
                "Données d'exemple. L'annuaire réel arrive avec la synchronisation.",
                style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _card(BuildContext context, Pharmacy p) {
    final t = Theme.of(context).textTheme;
    final selected = _selected?.id == p.id;
    final km = distanceKm(_origin, p.position);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? SifaColors.brand : Colors.transparent, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _select(p),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Tx(p.name, style: t.titleMedium),
            const SizedBox(height: 2),
            Tx(
              _me == null ? trf('{0} · depuis le centre · {1} · {2}', [tr(p.area), formatKm(km), tr(p.hours)]) : trf('{0} · à {1} · {2}', [tr(p.area), formatKm(km), tr(p.hours)]),
              style: t.bodyMedium,
            ),
            const SizedBox(height: 8),
            StatusChip(p.stock, p.stockLabel),
            if (selected) ...[
              const SizedBox(height: 12),
              if (_route != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Tx(
                    trf('Itinéraire : {0} · environ {1} min en voiture', [formatKm(_route!.km), _route!.duration.inMinutes]),
                    style: t.titleSmall,
                  ),
                ),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  onPressed: _routing ? null : () => _showRoute(p),
                  icon: _routing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.directions),
                  label: const Tx('Itinéraire'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openMaps(p),
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Tx('Ouvrir dans Maps'),
                ),
                if (p.phone != null)
                  OutlinedButton.icon(
                    onPressed: () => _call(p),
                    icon: const Icon(Icons.call),
                    label: const Tx('Appeler'),
                  ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
