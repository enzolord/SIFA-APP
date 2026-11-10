import 'package:flutter/foundation.dart';

/// Onglet actif de la barre de navigation (pour changer d'onglet depuis n'importe quel écran).
class AppNav {
  AppNav._();
  static const home = 0, history = 1, scan = 2, community = 3, profile = 4;
  static final tab = ValueNotifier<int>(home);
  static void go(int i) => tab.value = i;
}
