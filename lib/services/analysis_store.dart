import 'package:flutter/foundation.dart';

import '../models/diagnosis.dart';
import 'analytics.dart';
import 'classifier.dart';
import 'triage.dart';

/// Historique des analyses. Les photos sont enregistrées sur le téléphone
/// par [photoSaver] (branché par Persistence) ; la liste est rechargée au démarrage.
class AnalysisStore extends ChangeNotifier {
  AnalysisStore._();
  static final instance = AnalysisStore._();

  /// Remplacé par TfliteClassifier au démarrage (main.dart) ; le factice ne sert qu'aux tests.
  Classifier classifier = MockClassifier();
  Future<String?> Function(Uint8List bytes)? photoSaver;

  final List<Diagnosis> _items = [];
  List<Diagnosis> get items => List.unmodifiable(_items.reversed);
  Diagnosis? get last => _items.isEmpty ? null : _items.last;

  /// Référence anonyme d'une analyse : relie l'avis de l'éleveur à son résultat.
  static String refOf(Diagnosis d) => d.at.millisecondsSinceEpoch.toString();

  /// Statistiques d'usage : résultat et fiabilité seulement, jamais la photo.
  void _track(Diagnosis d) {
    final probs = d.photoProbs;
    Analytics.instance.track('analyse', {
      'ref': refOf(d),
      'maladie': d.disease.name,
      'confiance': double.parse(d.confidence.clamp(0.0, 1.0).toStringAsFixed(3)),
      'fiabilite': d.reliability.name,
      'questions': d.signs.length,
      if (probs != null) 'photo': Disease.values[Triage.argmax(probs)].name,
      if (probs != null) 'alerte': Triage.combine(probs, d.signs).redFlag,
    });
  }

  void add(Diagnosis d) {
    _items.add(d);
    notifyListeners();
    _track(d);
    final saver = photoSaver;
    if (saver != null && d.photoPath == null) {
      saver(d.photo).then((path) {
        if (path != null) {
          d.photoPath = path;
          notifyListeners();
        }
      });
    }
  }

  List<Map<String, dynamic>> toJson() => [
        for (final d in _items.where((d) => d.photoPath != null)) d.toJson(),
      ];

  Future<void> restore(
    Object? raw,
    Future<Uint8List?> Function(String path) loader,
  ) async {
    _items.clear();
    for (final x in (raw as List? ?? const [])) {
      final j = Map<String, dynamic>.from(x as Map);
      final path = j['photoPath'] as String?;
      final bytes = path == null ? null : await loader(path);
      if (bytes == null) continue;
      final probs = (j['probs'] as List?)?.map((e) => (e as num).toDouble()).toList();
      _items.add(Diagnosis(
        disease: Disease.values[(j['disease'] as int).clamp(0, Disease.values.length - 1)],
        confidence: (j['confidence'] as num).toDouble(),
        photo: bytes,
        at: DateTime.parse(j['at'] as String),
        photoPath: path,
        photoProbs: probs != null && probs.length == Disease.values.length ? probs : null,
        signs: {for (final s in (j['signs'] as List? ?? const [])) s as String},
        reliability: Reliability.values[(j['rel'] as int? ?? 1).clamp(0, Reliability.values.length - 1)],
      ));
    }
    notifyListeners();
  }
}
