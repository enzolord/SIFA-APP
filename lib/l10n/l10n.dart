import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'strings_en.dart';

/// Langue de l'interface (français par défaut, anglais au choix).
/// Les textes sont écrits en français dans le code ; l'anglais vient du catalogue [enStrings].
class L10n extends ChangeNotifier {
  L10n._();
  static final instance = L10n._();

  String _lang = 'fr';
  String get lang => _lang;
  static bool get en => instance._lang == 'en';
  Locale get locale => Locale(_lang);

  void set(String lang) {
    if (lang == _lang || (lang != 'fr' && lang != 'en')) return;
    _lang = lang;
    notifyListeners();
  }

  /// Au premier lancement : anglais si le téléphone est en anglais, sinon français.
  void detectFromDevice() {
    final code = ui.PlatformDispatcher.instance.locale.languageCode;
    _lang = code == 'en' ? 'en' : 'fr';
  }

  /// Décimale à 1 chiffre : virgule en français, point en anglais.
  static String dec1(double v) {
    final s = v.toStringAsFixed(1);
    return en ? s : s.replaceAll('.', ',');
  }
}

/// Traduit un texte français (renvoie le texte tel quel s'il n'y a pas de traduction).
String tr(String fr) => L10n.en ? (enStrings[fr] ?? fr) : fr;

/// Traduit un gabarit avec variables : `trf('sur {0}', [12])`.
String trf(String fr, List<Object> args) {
  var s = L10n.en ? (enTemplates[fr] ?? fr) : fr;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}

extension Dec1 on double {
  String get dec1 => L10n.dec1(this);
}

/// Comme [Text], mais traduit automatiquement selon la langue choisie.
class Tx extends StatelessWidget {
  const Tx(this.data, {super.key, this.style, this.maxLines, this.overflow, this.textAlign});
  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) =>
      Text(tr(data), style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign);
}
