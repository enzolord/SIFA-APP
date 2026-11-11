import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/diagnosis.dart';

/// Contrat du classifieur. Le Sprint 1 branchera l'implémentation TFLite.
abstract class Classifier {
  /// Renvoie null si l'image est inutilisable (confiance trop faible).
  Future<Diagnosis?> classify(Uint8List photo);
}

/// DÉMO UNIQUEMENT : renvoie un résultat factice déterministe.
/// À remplacer par TfliteClassifier (spike US-200).
class MockClassifier implements Classifier {
  @override
  Future<Diagnosis?> classify(Uint8List photo) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (photo.isEmpty) return null;
    final h = photo.length % 4;
    return Diagnosis(
      disease: Disease.values[h],
      confidence: 0.80 + (photo.length % 15) / 100,
      photo: photo,
    );
  }
}

/// Vrai classifieur : EfficientNet-B0 entraîné sur les fientes (assets/model/sifa_fp16.tflite).
/// Entrée : image 224x224 RGB, valeurs 0..255 (la normalisation est dans le modèle).
/// Sortie : 4 probabilités, dans l'ordre de assets/model/labels.json.
class TfliteClassifier implements Classifier {
  static const _asset = 'assets/model/sifa_fp16.tflite';
  static const _size = 224;

  /// Ordre des sorties du modèle (labels.json).
  static const _order = [
    Disease.coccidiosis,
    Disease.healthy,
    Disease.newcastle,
    Disease.salmonella,
  ];

  /// En dessous, la photo est jugée inutilisable ou trop ambiguë.
  static const minConfidence = 0.55;

  Interpreter? _interpreter;

  Future<Interpreter> _load() async =>
      _interpreter ??= await Interpreter.fromAsset(_asset, options: InterpreterOptions()..threads = 2);

  @override
  Future<Diagnosis?> classify(Uint8List photo) async {
    if (photo.isEmpty) return null;
    try {
      final interpreter = await _load();

      final codec = await ui.instantiateImageCodec(photo, targetWidth: _size, targetHeight: _size);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      if (data == null) return null;

      final rgba = data.buffer.asUint8List();
      final input = Float32List(_size * _size * 3);
      for (var i = 0, j = 0; i < rgba.length; i += 4) {
        input[j++] = rgba[i].toDouble();
        input[j++] = rgba[i + 1].toDouble();
        input[j++] = rgba[i + 2].toDouble();
      }

      final output = [List<double>.filled(_order.length, 0)];
      interpreter.run(input.reshape([1, _size, _size, 3]), output);

      final probs = output[0];
      var best = 0;
      for (var k = 1; k < probs.length; k++) {
        if (probs[k] > probs[best]) best = k;
      }
      if (probs[best] < minConfidence) return null;
      return Diagnosis(disease: _order[best], confidence: probs[best], photo: photo);
    } catch (e) {
      debugPrint('TfliteClassifier: $e');
      return null;
    }
  }
}
