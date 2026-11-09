import 'package:flutter_test/flutter_test.dart';
import 'package:sifa/main.dart';

void main() {
  testWidgets('affiche les 5 onglets', (tester) async {
    await tester.pumpWidget(const SifaApp());
    for (final l in ['Accueil', 'Historique', 'Scanner', 'Conseils', 'Profil']) {
      expect(find.text(l), findsWidgets);
    }
  });
}
