import 'dart:typed_data';

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
