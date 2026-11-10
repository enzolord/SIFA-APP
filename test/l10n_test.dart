import 'package:flutter_test/flutter_test.dart';
import 'package:sifa/l10n/l10n.dart';

void main() {
  tearDown(() => L10n.instance.set('fr'));

  test('français : les textes restent tels quels', () {
    expect(tr('Accueil'), 'Accueil');
    expect(trf('sur {0}', [12]), 'sur 12');
    expect(1.5.dec1, '1,5');
  });

  test('anglais : traduction, gabarits et décimales', () {
    L10n.instance.set('en');
    expect(tr('Accueil'), 'Home');
    expect(tr('Texte inconnu'), 'Texte inconnu');
    expect(trf('sur {0}', [12]), 'of 12');
    expect(trf('Jour {0} · dans {1} jours', [5, 3]), 'Day 5 · in 3 days');
    expect(1.5.dec1, '1.5');
  });
}
