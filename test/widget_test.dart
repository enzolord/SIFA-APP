import 'package:flutter_test/flutter_test.dart';
import 'package:sifa/main.dart';
import 'package:sifa/services/session.dart';

void main() {
  testWidgets('affiche les 5 onglets', (tester) async {
    Session.instance.completeOnboarding(
        phone: '+237 600000000', farmName: 'Test', type: FlockType.broiler, headcount: 10);
    await tester.pumpWidget(const SifaApp());
    for (final l in ['Accueil', 'Historique', 'Scanner', 'Conseils', 'Profil']) {
      expect(find.text(l), findsWidgets);
    }
  });
}
