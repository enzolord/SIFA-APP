import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/l10n.dart';
import 'screens/onboarding_flow.dart';
import 'screens/shell.dart';
import 'services/persistence.dart';
import 'services/session.dart';
import 'theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Persistence.init();
  runApp(const SifaApp());
}

class SifaApp extends StatelessWidget {
  const SifaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Session.instance, L10n.instance]),
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
        home: Session.instance.onboarded
            ? Shell(key: ValueKey(L10n.instance.lang))
            : const OnboardingFlow(),
      ),
    );
  }
}
