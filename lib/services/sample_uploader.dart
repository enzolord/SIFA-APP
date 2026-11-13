import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import '../models/diagnosis.dart';
import 'analysis_store.dart';
import 'analytics.dart';
import '../l10n/l10n.dart';

/// Partage de photos de fientes pour améliorer le modèle, uniquement avec l'accord de l'éleveur.
///
/// Deux façons de donner son accord : partager une photo précise depuis l'écran de résultat,
/// ou activer le partage automatique dans Profil. La photo est envoyée sans nom, avec
/// l'identifiant aléatoire du téléphone, et validée ensuite par un vétérinaire dans
/// l'administration avant d'entrer dans le jeu d'entraînement.
class SampleUploader extends ChangeNotifier {
  SampleUploader._();
  static final instance = SampleUploader._();

  /// Remplaçable dans les tests.
  static http.Client client = http.Client();

  /// Photos plus lourdes : ignorées (le serveur refuse au-delà de 2 Mo).
  static const maxBytes = 2 * 1024 * 1024;

  File? _file;
  bool _auto = false;
  final Set<String> _sent = {};

  /// Partage automatique de chaque photo analysée (désactivé par défaut).
  bool get auto => _auto;

  bool wasShared(Diagnosis d) => _sent.contains(AnalysisStore.refOf(d));

  Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}/partage.json');
      if (await _file!.exists()) {
        final j = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        _auto = j['auto'] as bool? ?? false;
        _sent.addAll(((j['envoyes'] as List?) ?? const []).cast<String>());
      }
    } catch (e) {
      debugPrint('SampleUploader lecture : $e');
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final recent = _sent.length > 300 ? _sent.skip(_sent.length - 300).toList() : _sent.toList();
      await _file?.writeAsString(jsonEncode({'auto': _auto, 'envoyes': recent}), flush: true);
    } catch (_) {}
  }

  Future<void> setAuto(bool v) async {
    _auto = v;
    notifyListeners();
    await _save();
  }

  /// Appelé après chaque analyse : n'envoie que si le partage automatique est actif.
  void onAnalysis(Diagnosis d) {
    if (_auto) unawaited(share(d));
  }

  /// Envoie la photo et ses informations. Renvoie false si l'envoi échoue (réseau, serveur).
  Future<bool> share(Diagnosis d) async {
    final device = Analytics.instance.deviceId;
    final ref = AnalysisStore.refOf(d);
    final Uint8List bytes = d.photo;
    if (device.length < 8 || bytes.isEmpty || bytes.length > maxBytes) return false;
    if (_sent.contains(ref)) return true;
    final path = '$device/$ref.jpg';
    final base = AppConfig.supabaseUrl;
    final headers = {'apikey': AppConfig.supabaseKey, 'Authorization': 'Bearer ${AppConfig.supabaseKey}'};
    try {
      final up = await client
          .post(Uri.parse('$base/storage/v1/object/echantillons/$path'),
              headers: {...headers, 'Content-Type': 'image/jpeg', 'x-upsert': 'true'}, body: bytes)
          .timeout(const Duration(seconds: 40));
      if (up.statusCode != 200 && up.statusCode != 201) {
        debugPrint('Partage photo refusé ${up.statusCode}');
        return false;
      }
      final row = await client
          .post(Uri.parse('$base/rest/v1/echantillons?on_conflict=appareil,ref'),
              headers: {...headers, 'Content-Type': 'application/json', 'Prefer': 'resolution=ignore-duplicates,return=minimal'},
              body: jsonEncode({
                'appareil': device,
                'ref': ref,
                'photo_path': path,
                'maladie_app': d.disease.name,
                'confiance': double.parse(d.confidence.clamp(0.0, 1.0).toStringAsFixed(3)),
                'fiabilite': d.reliability.name,
                'signes': d.signs.toList(),
                'langue': L10n.instance.lang,
                'version_app': AppConfig.appVersion,
              }))
          .timeout(const Duration(seconds: 15));
      if (row.statusCode < 200 || row.statusCode >= 300) {
        debugPrint('Partage fiche refusé ${row.statusCode}');
        return false;
      }
      _sent.add(ref);
      unawaited(_save());
      Analytics.instance.action('photo_partagee');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Partage photo hors connexion : $e');
      return false;
    }
  }
}
