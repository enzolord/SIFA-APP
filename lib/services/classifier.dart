import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/diagnosis.dart';

/// Pourquoi une photo est refusée avant tout résultat.
enum ScanIssue {
  /// Photo trop sombre.
  tooDark,

  /// Surface unie (mur, tissu, objet lisse) : rien qui ressemble à une fiente.
  tooPlain,

  /// Le modèle reconnaît autre chose qu'une fiente (classe « Autre »).
  notDropping,

  /// Le modèle hésite : photo floue, mal cadrée ou ambiguë.
  unclear,

  /// Le modèle n'a pas pu être chargé ou exécuté.
  modelError,
}

class ScanOutcome {
  const ScanOutcome.ok(List<double> this.probs) : issue = null;
  const ScanOutcome.rejected(ScanIssue this.issue) : probs = null;

  /// Probabilités par maladie, dans l'ordre de [Disease.values].
  final List<double>? probs;
  final ScanIssue? issue;

  bool get ok => probs != null;
}

/// Contrat du classifieur de photos.
abstract class Classifier {
  Future<ScanOutcome> analyze(Uint8List photo);
}

/// Pour les tests automatiques uniquement : renvoie un résultat déterministe sans modèle.
class MockClassifier implements Classifier {
  @override
  Future<ScanOutcome> analyze(Uint8List photo) async {
    if (photo.isEmpty) return const ScanOutcome.rejected(ScanIssue.unclear);
    final probs = List<double>.filled(Disease.values.length, 0.05);
    probs[photo.length % Disease.values.length] = 0.85;
    return ScanOutcome.ok(probs);
  }
}

/// Classifieur embarqué : EfficientNet-B0 entraîné sur des photos de fientes
/// (assets/model/sifa_fp16.tflite). Fonctionne sans Internet.
///
/// Entrée : image 224x224 RGB, valeurs 0..255 (la normalisation est dans le modèle).
/// Sortie : une probabilité par étiquette de assets/model/labels.json. Une étiquette
/// qui n'est pas une maladie connue (« Autre ») sert à refuser les photos qui ne
/// montrent pas une fiente ; le modèle actuel n'en a pas encore, le suivant en aura une.
class TfliteClassifier implements Classifier {
  static const _modelAsset = 'assets/model/sifa_fp16.tflite';
  static const _labelsAsset = 'assets/model/labels.json';
  static const _size = 224;

  /// En dessous, le modèle hésite trop : on demande une autre photo.
  static const minConfidence = 0.55;

  Interpreter? _interpreter;

  /// Pour chaque sortie du modèle : la maladie correspondante, ou null pour « Autre ».
  List<Disease?> _outputs = const [];

  static Disease? diseaseForLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('cocci')) return Disease.coccidiosis;
    if (l.contains('salmo')) return Disease.salmonella;
    if (l.contains('castle') || l.contains('ncd')) return Disease.newcastle;
    if (l.contains('health') || l.contains('sain')) return Disease.healthy;
    return null;
  }

  Future<Interpreter> _load() async {
    final existing = _interpreter;
    if (existing != null) return existing;
    final labels = (jsonDecode(await rootBundle.loadString(_labelsAsset)) as List).cast<String>();
    _outputs = [for (final l in labels) diseaseForLabel(l)];
    return _interpreter = await Interpreter.fromAsset(_modelAsset, options: InterpreterOptions()..threads = 2);
  }

  @override
  Future<ScanOutcome> analyze(Uint8List photo) async {
    if (photo.isEmpty) return const ScanOutcome.rejected(ScanIssue.unclear);
    try {
      final interpreter = await _load();

      final codec = await ui.instantiateImageCodec(photo, targetWidth: _size, targetHeight: _size);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      if (data == null) return const ScanOutcome.rejected(ScanIssue.unclear);
      final rgba = data.buffer.asUint8List();

      final quality = checkQuality(rgba);
      if (quality != null) return ScanOutcome.rejected(quality);

      // Trois vues de la même photo (originale, miroir horizontal, miroir vertical) :
      // une vraie fiente donne le même résultat dans les trois cas.
      final n = _outputs.length;
      final sum = List<double>.filled(n, 0);
      final tops = <int>[];
      for (final view in const [0, 1, 2]) {
        final output = [List<double>.filled(n, 0)];
        interpreter.run(_toInput(rgba, view).reshape([1, _size, _size, 3]), output);
        final p = output[0];
        var best = 0;
        for (var k = 0; k < n; k++) {
          sum[k] += p[k] / 3;
          if (p[k] > p[best]) best = k;
        }
        tops.add(best);
      }
      return interpret(sum, _outputs, viewsAgree: tops.toSet().length == 1);
    } catch (e) {
      debugPrint('TfliteClassifier: $e');
      return const ScanOutcome.rejected(ScanIssue.modelError);
    }
  }

  /// Contrôles simples avant le modèle. Seuils volontairement prudents : on ne refuse
  /// que les photos manifestement inutilisables.
  @visibleForTesting
  static ScanIssue? checkQuality(Uint8List rgba) {
    final count = rgba.length ~/ 4;
    if (count == 0) return ScanIssue.unclear;
    var s = 0.0, s2 = 0.0;
    for (var i = 0; i < rgba.length; i += 4) {
      final y = 0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2];
      s += y;
      s2 += y * y;
    }
    final mean = s / count;
    final std = math.sqrt(math.max(0, s2 / count - mean * mean));
    if (mean < 28) return ScanIssue.tooDark;
    if (std < 10) return ScanIssue.tooPlain;
    return null;
  }

  /// Transforme les sorties moyennées du modèle en résultat ou en refus.
  @visibleForTesting
  static ScanOutcome interpret(List<double> avg, List<Disease?> outputs, {required bool viewsAgree}) {
    var other = 0.0;
    final probs = List<double>.filled(Disease.values.length, 0);
    for (var k = 0; k < avg.length; k++) {
      final d = outputs[k];
      if (d == null) {
        other += avg[k];
      } else {
        probs[d.index] += avg[k];
      }
    }
    if (other >= 0.5) return const ScanOutcome.rejected(ScanIssue.notDropping);
    final total = probs.reduce((a, b) => a + b);
    if (total <= 0) return const ScanOutcome.rejected(ScanIssue.unclear);
    for (var i = 0; i < probs.length; i++) {
      probs[i] /= total;
    }
    final top = probs.reduce(math.max);
    if (top < minConfidence) return const ScanOutcome.rejected(ScanIssue.unclear);
    if (!viewsAgree && top < 0.75) return const ScanOutcome.rejected(ScanIssue.unclear);
    return ScanOutcome.ok(probs);
  }

  /// view : 0 = originale, 1 = miroir horizontal, 2 = miroir vertical.
  static Float32List _toInput(Uint8List rgba, int view) {
    final input = Float32List(_size * _size * 3);
    var j = 0;
    for (var y = 0; y < _size; y++) {
      final sy = view == 2 ? _size - 1 - y : y;
      for (var x = 0; x < _size; x++) {
        final sx = view == 1 ? _size - 1 - x : x;
        final i = (sy * _size + sx) * 4;
        input[j++] = rgba[i].toDouble();
        input[j++] = rgba[i + 1].toDouble();
        input[j++] = rgba[i + 2].toDouble();
      }
    }
    return input;
  }
}
