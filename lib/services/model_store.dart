import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import '../models/diagnosis.dart';
import 'classifier.dart';

enum ModelUpdate { upToDate, updated, offline, invalid }

/// Annonce d'un modèle publié (fichier manifest.json du bucket Supabase « modeles »).
class ModelManifest {
  const ModelManifest({
    required this.version,
    required this.file,
    required this.labels,
    required this.sha256,
    required this.size,
  });

  final int version;
  final String file;
  final List<String> labels;
  final String sha256;
  final int size;

  /// Renvoie null si le manifeste est incomplet ou incohérent.
  static ModelManifest? parse(String body) {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      final m = ModelManifest(
        version: (j['version'] as num).toInt(),
        file: j['fichier'] as String,
        labels: (j['labels'] as List).cast<String>(),
        sha256: (j['sha256'] as String).toLowerCase(),
        size: (j['taille'] as num).toInt(),
      );
      return m.isValid ? m : null;
    } catch (_) {
      return null;
    }
  }

  /// Le modèle doit connaître les quatre résultats de SIFA, et son fichier doit être un simple nom.
  bool get isValid {
    final known = {for (final l in labels) TfliteClassifier.diseaseForLabel(l)};
    return version > 0 &&
        size > 100000 &&
        size < 60000000 &&
        sha256.length == 64 &&
        RegExp(r'^[A-Za-z0-9_.-]+\.tflite$').hasMatch(file) &&
        Disease.values.every(known.contains);
  }
}

/// Modèle d'analyse utilisé par l'application.
///
/// Un modèle est livré dans l'application. Quand un modèle plus récent est publié dans
/// Supabase (après un nouvel entraînement), l'application le télécharge, le vérifie et
/// l'utilise, sans nouvelle installation. En cas de problème, elle revient au modèle livré.
class ModelStore extends ChangeNotifier {
  ModelStore._();
  static final instance = ModelStore._();

  /// Remplaçable dans les tests.
  static http.Client client = http.Client();

  Directory? _dir;
  int _version = AppConfig.bundledModelVersion;
  String? _path;
  List<String>? _labels;
  bool _busy = false;

  /// Version du modèle actif (celui livré dans l'application tant qu'aucun autre n'est installé).
  int get version => _version;

  /// Fichier du modèle téléchargé, ou null pour le modèle livré dans l'application.
  String? get path => _path;
  List<String>? get labels => _labels;
  bool get busy => _busy;
  bool get isBundled => _path == null;

  File get _stateFile => File('${_dir!.path}/actuel.json');

  Future<void> init() async {
    try {
      final base = await getApplicationSupportDirectory();
      _dir = Directory('${base.path}/modele');
      await _dir!.create(recursive: true);
      if (await _stateFile.exists()) {
        final j = jsonDecode(await _stateFile.readAsString()) as Map<String, dynamic>;
        final file = File('${_dir!.path}/${j['fichier']}');
        final v = (j['version'] as num).toInt();
        if (await file.exists() && v > AppConfig.bundledModelVersion) {
          _version = v;
          _path = file.path;
          _labels = (j['labels'] as List).cast<String>();
        }
      }
    } catch (e) {
      debugPrint('ModelStore.init: $e');
      _reset();
    }
    notifyListeners();
  }

  void _reset() {
    _version = AppConfig.bundledModelVersion;
    _path = null;
    _labels = null;
  }

  /// Le modèle téléchargé ne se charge pas : on l'efface et on revient au modèle livré.
  Future<void> discardDownloaded() async {
    final p = _path;
    _reset();
    notifyListeners();
    try {
      if (p != null) await File(p).delete();
      if (_dir != null && await _stateFile.exists()) await _stateFile.delete();
    } catch (_) {}
  }

  /// Cherche un modèle plus récent ; le télécharge et l'active s'il est valide.
  Future<ModelUpdate> checkForUpdate() async {
    final dir = _dir;
    if (dir == null || _busy) return ModelUpdate.offline;
    _busy = true;
    notifyListeners();
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final r = await client
          .get(Uri.parse('${AppConfig.modelManifestUrl}?t=$stamp'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 404 || r.statusCode == 400) return ModelUpdate.upToDate; // rien de publié
      if (r.statusCode != 200) return ModelUpdate.offline;
      final m = ModelManifest.parse(utf8.decode(r.bodyBytes));
      if (m == null) return ModelUpdate.invalid;
      if (m.version <= _version) return ModelUpdate.upToDate;

      final d = await client
          .get(Uri.parse('${AppConfig.modelBaseUrl}${m.file}'))
          .timeout(const Duration(minutes: 3));
      if (d.statusCode != 200) return ModelUpdate.offline;
      final bytes = d.bodyBytes;
      if (bytes.length != m.size || sha256.convert(bytes).toString() != m.sha256) {
        return ModelUpdate.invalid; // fichier tronqué ou modifié
      }

      final target = File('${dir.path}/${m.file}');
      final tmp = File('${target.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(target.path);
      final old = _path;
      await _stateFile.writeAsString(
        jsonEncode({'version': m.version, 'fichier': m.file, 'labels': m.labels}),
        flush: true,
      );
      _version = m.version;
      _path = target.path;
      _labels = m.labels;
      if (old != null && old != target.path) {
        try {
          await File(old).delete();
        } catch (_) {}
      }
      return ModelUpdate.updated;
    } catch (e) {
      debugPrint('ModelStore.checkForUpdate: $e');
      return ModelUpdate.offline;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
