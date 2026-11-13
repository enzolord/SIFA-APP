import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../l10n/l10n.dart';
import '../models/pharmacy.dart';
import '../widgets/status_chip.dart';

/// Texte venant de l'administration : `{"fr": "...", "en": "..."}` ou simple chaîne.
/// Renvoie la langue courante, avec repli sur le français.
String localized(Object? v, {String? lang}) {
  if (v is String) return v;
  if (v is Map) {
    final l = lang ?? L10n.instance.lang;
    final t = v[l];
    if (t is String && t.trim().isNotEmpty) return t;
    final fr = v['fr'];
    if (fr is String) return fr;
  }
  return '';
}

/// Annonce affichée en haut de l'accueil.
class Announcement {
  const Announcement(this.level, this.title, this.text);
  final String level; // info | warn | danger
  final String title;
  final String text;
}

/// Contenu modifiable à distance depuis l'outil d'administration.
///
/// L'application fonctionne toujours hors connexion : le dernier contenu reçu est gardé sur
/// le téléphone, et le contenu intégré à l'application sert de repli. Quand le téléphone est
/// en ligne, toute modification faite dans l'administration arrive en quelques secondes.
class RemoteContent extends ChangeNotifier with WidgetsBindingObserver {
  RemoteContent._();
  static final instance = RemoteContent._();

  /// Remplaçable dans les tests.
  static http.Client client = http.Client();

  Map<String, dynamic> _content = {};
  List<Pharmacy>? _pharmacies; // null : jamais reçu
  File? _cache;
  bool _started = false;
  Timer? _debounce;

  /// Liste reçue du serveur, ou null si l'application n'a encore jamais pu la lire.
  List<Pharmacy>? get pharmacies => _pharmacies;

  Map<String, dynamic> section(String key) {
    final v = _content[key];
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }

  Announcement? get announcement {
    final a = section('annonce');
    if (a['actif'] != true) return null;
    final title = localized(a['titre']);
    final text = localized(a['texte']);
    if (title.isEmpty && text.isEmpty) return null;
    final level = a['niveau'] is String ? a['niveau'] as String : 'info';
    return Announcement(level, title, text);
  }

  /// Message de maintenance, ou null si l'application est ouverte.
  String? get maintenanceMessage {
    final m = section('maintenance');
    if (m['actif'] != true) return null;
    final msg = localized(m['message']);
    return msg.isEmpty ? 'SIFA est en maintenance.' : msg;
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final dir = await getApplicationSupportDirectory();
      _cache = File('${dir.path}/contenu_distant.json');
      if (await _cache!.exists()) {
        applyJson(jsonDecode(await _cache!.readAsString()) as Map<String, dynamic>, notify: false);
      }
    } catch (e) {
      debugPrint('RemoteContent cache : $e');
    }
    notifyListeners();
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());
    _listenRealtime();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  /// Écoute les changements en direct ; sans connexion ou sans Realtime, le rafraîchissement
  /// au retour dans l'application prend le relais.
  void _listenRealtime() {
    try {
      final sb = Supabase.instance.client;
      void changed(PostgresChangePayload _) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 600), () => unawaited(refresh()));
      }

      sb
          .channel('contenu-sifa')
          .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'contenu', callback: changed)
          .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'pharmacies', callback: changed)
          .subscribe();
    } catch (e) {
      debugPrint('RemoteContent temps réel : $e');
    }
  }

  Future<Object?> _get(String path) async {
    final r = await client
        .get(Uri.parse('${AppConfig.supabaseUrl}/rest/v1/$path'), headers: {
      'apikey': AppConfig.supabaseKey,
      'Authorization': 'Bearer ${AppConfig.supabaseKey}',
    }).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) throw HttpException('HTTP ${r.statusCode} sur $path');
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  /// Relit le contenu sur le serveur. Sans réseau, on garde ce que le téléphone a déjà.
  Future<bool> refresh() async {
    try {
      final contenu = await _get('contenu?select=cle,valeur') as List;
      final pharma = await _get('pharmacies?select=*&actif=eq.true') as List;
      final snapshot = {
        'contenu': {for (final row in contenu) (row as Map)['cle'] as String: row['valeur']},
        'pharmacies': pharma,
      };
      applyJson(snapshot);
      try {
        await _cache?.writeAsString(jsonEncode(snapshot), flush: true);
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('RemoteContent.refresh : $e');
      return false;
    }
  }

  @visibleForTesting
  void applyJson(Map<String, dynamic> snapshot, {bool notify = true}) {
    final c = snapshot['contenu'];
    _content = c is Map ? Map<String, dynamic>.from(c) : {};
    final p = snapshot['pharmacies'];
    _pharmacies = p is List
        ? [for (final row in p) if (parsePharmacy(row) != null) parsePharmacy(row)!]
        : _pharmacies;
    if (notify) notifyListeners();
  }

  /// Ligne de la table `pharmacies` -> pharmacie de l'application (null si incomplète).
  @visibleForTesting
  static Pharmacy? parsePharmacy(Object? row) {
    try {
      final j = row as Map;
      final lat = (j['latitude'] as num).toDouble();
      final lng = (j['longitude'] as num).toDouble();
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
      final (status, label) = switch (j['stock']) {
        'en_stock' => (SifaStatus.ok, 'En stock'),
        'limite' => (SifaStatus.warn, 'Stock limité'),
        'rupture' => (SifaStatus.danger, 'Rupture'),
        _ => (SifaStatus.neutral, 'Stock non renseigné'),
      };
      final quartier = (j['quartier'] as String?) ?? '';
      final ville = (j['ville'] as String?) ?? '';
      final tel = (j['telephone'] as String?)?.trim();
      final horaires = (j['horaires'] as String?)?.trim() ?? '';
      return Pharmacy(
        id: '${j['id']}',
        name: j['nom'] as String,
        area: quartier.isEmpty ? ville : quartier,
        position: LatLng(lat, lng),
        phone: (tel == null || tel.isEmpty) ? null : tel,
        hours: horaires.isEmpty ? 'Horaires non renseignés' : horaires,
        stock: status,
        stockLabel: label,
      );
    } catch (_) {
      return null;
    }
  }
}
