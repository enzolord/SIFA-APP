import 'package:flutter/foundation.dart';

import '../models/diagnosis.dart';
import 'classifier.dart';

/// Stockage en mémoire (remplacé par SQLite local puis Supabase).
class AnalysisStore extends ChangeNotifier {
  AnalysisStore._();
  static final instance = AnalysisStore._();

  Classifier classifier = MockClassifier();
  final List<Diagnosis> _items = [];
  List<Diagnosis> get items => List.unmodifiable(_items.reversed);
  Diagnosis? get last => _items.isEmpty ? null : _items.last;

  void add(Diagnosis d) {
    _items.add(d);
    notifyListeners();
  }
}
