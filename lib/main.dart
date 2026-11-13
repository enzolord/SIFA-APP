import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/l10n.dart';
import 'screens/onboarding_flow.dart';
import 'screens/shell.dart';
import 'services/analysis_store.dart';
import 'services/analytics.dart';
import 'services/auth_service.dart';
import 'services/classifier.dart';
import 'services/entitlement.dart';
import 'services/model_store.dart';
import 'services/persistence.dart';
import 'services/remote_content.dart';
import 'services/sample_uploader.dart';
import 'services/session.dart';
import 'theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AnalysisStore.instance.classifier = TfliteClassifier();
  await Persistence.init();
  await AuthService.instance.init();
  await ModelStore.instance.init();
  // Cherche en arrière-plan un modèle plus récent publié après un nouvel entraînement.
  ModelStore.instance.checkForUpdate();
  // Contenu modifiable à distance (annonces, pharmacies, formules, fiches) : cache puis mise à jour en direct.
  RemoteContent.instance.start();
  Entitlement.instance.start();
  Entitlement.instance.refresh();
  // Mesure d'usage anonyme (désactivable dans Profil).
  Analytics.instance.start().then((_) => SampleUploader.instance.init());
  runApp(const SifaApp());
}

class SifaApp extends StatelessWidget {
  const SifaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Session.instance, L10n.instance, RemoteContent.instance]),
      builder: (context, _) => MaterialApp(
        title: 'SIFA',
        debugShowCheckedModeBanner: false,
        theme: sifaLightTheme(),
        darkTheme: sifaDarkTheme(),
        themeMode: ThemeMode.system,
        locale: L10n.instance.locale,
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        navigatorObservers: [Analytics.instance.observer],
        builder: (context, child) {
          final maintenance = RemoteContent.instance.maintenanceMessage;
          if (maintenance == null) return child!;
          return _MaintenanceScreen(message: localizedMaintenance(maintenance));
        },
        home: Session.instance.onboarded
            ? Shell(key: ValueKey(L10n.instance.lang))
            : const OnboardingFlow(),
      ),
    );
  }
}

/// Le message vient de l'administration (déjà dans la bonne langue) ; le message par défaut est traduit.
String localizedMaintenance(String m) => tr(m);

/// Écran affiché à la place de l'application quand l'administration active la maintenance.
class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.build_circle_outlined, size: 64),
              const SizedBox(height: 16),
              Text(message, style: t.titleLarge, textAlign: TextAlign.center),
            ]),
          ),
        ),
      ),
    );
  }
}
