import 'package:flutter/foundation.dart';

enum FlockType { broiler, layer }

extension FlockTypeLabel on FlockType {
  String get label => this == FlockType.broiler ? 'Poulets de chair' : 'Poules pondeuses';
}

/// État de session en mémoire (sera remplacé par Supabase + stockage local).
class Session extends ChangeNotifier {
  Session._();
  static final instance = Session._();

  bool onboarded = false;
  String phone = '';
  String farmName = '';
  FlockType flockType = FlockType.broiler;
  int headcount = 0;

  String get farmLine => farmName.isEmpty ? flockType.label : '$farmName · ${flockType.label}';

  Map<String, dynamic> toJson() => {
        'onboarded': onboarded,
        'phone': phone,
        'farmName': farmName,
        'flockType': flockType.index,
        'headcount': headcount,
      };

  void restore(Map<String, dynamic> j) {
    onboarded = j['onboarded'] as bool? ?? false;
    phone = j['phone'] as String? ?? '';
    farmName = j['farmName'] as String? ?? '';
    flockType = FlockType.values[(j['flockType'] as int? ?? 0).clamp(0, FlockType.values.length - 1)];
    headcount = j['headcount'] as int? ?? 0;
    notifyListeners();
  }

  void completeOnboarding({
    required String phone,
    required String farmName,
    required FlockType type,
    required int headcount,
  }) {
    this.phone = phone;
    this.farmName = farmName;
    flockType = type;
    this.headcount = headcount;
    onboarded = true;
    notifyListeners();
  }
}
