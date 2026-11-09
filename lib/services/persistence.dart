import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'analysis_store.dart';
import 'farm_store.dart';
import 'session.dart';

/// Sauvegarde locale : un fichier JSON + un dossier de photos dans les documents de l'app.
/// Écriture atomique (fichier temporaire puis renommage) pour éviter les fichiers corrompus.
class Persistence {
  Persistence._();

  static late Directory _dir;
  static Timer? _timer;
  static bool _ready = false;

  static File get _file => File('${_dir.path}/sifa.json');

  static Future<void> init() async {
    _dir = await getApplicationDocumentsDirectory();
    await Directory('${_dir.path}/photos').create(recursive: true);

    try {
      if (await _file.exists()) {
        final data = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
        if (data['session'] != null) {
          Session.instance.restore(Map<String, dynamic>.from(data['session'] as Map));
        }
        if (data['farm'] != null) {
          FarmStore.instance.restore(Map<String, dynamic>.from(data['farm'] as Map));
        }
        await AnalysisStore.instance.restore(data['analyses'], _readPhoto);
      }
    } catch (_) {
      // Fichier illisible : on repart à vide plutôt que de planter.
    }

    AnalysisStore.instance.photoSaver = _savePhoto;
    for (final l in [Session.instance, FarmStore.instance, AnalysisStore.instance]) {
      l.addListener(_schedule);
    }
    _ready = true;
  }

  static void _schedule() {
    if (!_ready) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), flush);
  }

  static Future<void> flush() async {
    final tmp = File('${_file.path}.tmp');
    final json = jsonEncode({
      'version': 1,
      'session': Session.instance.toJson(),
      'farm': FarmStore.instance.toJson(),
      'analyses': AnalysisStore.instance.toJson(),
    });
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(_file.path);
  }

  static Future<String?> _savePhoto(Uint8List bytes) async {
    try {
      final path = '${_dir.path}/photos/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await File(path).writeAsBytes(bytes, flush: true);
      return path;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _readPhoto(String path) async {
    try {
      final f = File(path);
      return await f.exists() ? await f.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }
}
