import 'package:flutter/material.dart';

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
    return MaterialApp(
      title: 'SIFA',
      debugShowCheckedModeBanner: false,
      theme: sifaLightTheme(),
      darkTheme: sifaDarkTheme(),
      themeMode: ThemeMode.system,
      home: ListenableBuilder(
        listenable: Session.instance,
        builder: (context, _) =>
            Session.instance.onboarded ? const Shell() : const OnboardingFlow(),
      ),
    );
  }
}
