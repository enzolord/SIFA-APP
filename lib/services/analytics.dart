import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import '../l10n/l10n.dart';
import 'nav.dart';

/// Mesure d'usage anonyme pour le tableau de bord d'administration.
///
/// Ce qui est envoyé : un identifiant aléatoire du téléphone, le nom de l'écran ou de
/// l'action, le résultat d'une analyse (maladie, fiabilité) et l'avis de l'éleveur.
/// Jamais : photo, nom, e-mail, téléphone, position. L'éleveur peut couper l'envoi
/// dans Profil. Hors connexion, les événements attendent et partent plus tard.
class Analytics with WidgetsBindingObserver {
  Analytics._();
  static final instance = Analytics._();

  /// Remplaçable dans les tests.
  static http.Client client = http.Client();

  static const _maxQueue = 500;
  static const _batch = 100;

  String _device = '';
  bool _enabled = true;
  File? _file;
  final List<Map<String, Object?>> _queue = [];
  DateTime? _lastOpen;

  bool get enabled => _enabled;

  /// Identifiant aléatoire de ce téléphone (vide tant que la mesure n'a pas démarré).
  String get deviceId => _device;
  @visibleForTesting
  List<Map<String, Object?>> get pending => List.unmodifiable(_queue);

  /// Observateur de navigation : enregistre les écrans ouverts (routes nommées).
  late final NavigatorObserver observer = _ScreenObserver(this);

  @visibleForTesting
  void debugInit({String device = 'testdevice0001', bool enabled = true}) {
    _device = device;
    _enabled = enabled;
    _queue.clear();
  }

  Future<void> start() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}/usage.json');
      if (await _file!.exists()) {
        final j = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        _device = (j['appareil'] as String?) ?? '';
        _enabled = j['actif'] as bool? ?? true;
      }
    } catch (e) {
      debugPrint('Analytics lecture : $e');
    }
    if (_device.length < 8) {
      _device = newDeviceId();
      await _save();
    }
    WidgetsBinding.instance.addObserver(this);
    AppNav.tab.addListener(() => screen(const ['Accueil', 'Historique', 'Scanner', 'Communaute', 'Profil'][AppNav.tab.value]));
    _opened();
  }

  @visibleForTesting
  static String newDeviceId() {
    final r = Random.secure();
    return List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  Future<void> _save() async {
    try {
      await _file?.writeAsString(jsonEncode({'appareil': _device, 'actif': _enabled}), flush: true);
    } catch (_) {}
  }

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    if (!v) _queue.clear();
    await _save();
  }

  void _opened() {
    final now = DateTime.now();
    // Une ouverture = lancement, ou retour dans l'application après plus de 30 minutes.
    if (_lastOpen == null || now.difference(_lastOpen!) > const Duration(minutes: 30)) {
      track('ouverture');
    }
    _lastOpen = now;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _opened();
      unawaited(flush());
    }
  }

  void screen(String name) => track('ecran', {'nom': name});
  void action(String name) => track('action', {'nom': name});

  void track(String name, [Map<String, Object?> props = const {}]) {
    if (!_enabled || _device.isEmpty) return;
    _queue.add({
      'appareil': _device,
      'nom': name,
      'props': props,
      'langue': L10n.instance.lang,
      'version_app': AppConfig.appVersion,
      'cree_le': DateTime.now().toUtc().toIso8601String(),
    });
    if (_queue.length > _maxQueue) _queue.removeRange(0, _queue.length - _maxQueue);
    unawaited(flush());
  }

  Future<void>? _running;

  /// Envoie la file ; si un envoi est déjà en cours, attend sa fin.
  Future<void> flush() {
    if (_queue.isEmpty || !_enabled) return _running ?? Future<void>.value();
    return _running ??= _send().whenComplete(() => _running = null);
  }

  Future<void> _send() async {
    try {
      while (_queue.isNotEmpty) {
        final n = min(_batch, _queue.length);
        final chunk = _queue.sublist(0, n);
        final r = await client
            .post(
              Uri.parse('${AppConfig.supabaseUrl}/rest/v1/evenements'),
              headers: {
                'apikey': AppConfig.supabaseKey,
                'Authorization': 'Bearer ${AppConfig.supabaseKey}',
                'Content-Type': 'application/json',
                'Prefer': 'return=minimal',
              },
              body: jsonEncode(chunk),
            )
            .timeout(const Duration(seconds: 10));
        if (r.statusCode == 201 || r.statusCode == 200 || r.statusCode == 204) {
          _queue.removeRange(0, min(n, _queue.length));
        } else if (r.statusCode >= 400 && r.statusCode < 500) {
          // Lot refusé (table absente, règle) : inutile de réessayer indéfiniment.
          debugPrint('Analytics refusé ${r.statusCode}');
          _queue.removeRange(0, min(n, _queue.length));
        } else {
          break;
        }
      }
    } catch (e) {
      debugPrint('Analytics hors connexion : $e');
    }
  }
}

class _ScreenObserver extends NavigatorObserver {
  _ScreenObserver(this._a);
  final Analytics _a;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null && name.isNotEmpty && name != '/') _a.screen(name);
  }
}
