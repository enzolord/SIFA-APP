import 'package:flutter/material.dart';

import 'screens/onboarding_flow.dart';
import 'screens/shell.dart';
import 'services/session.dart';
import 'theme/theme.dart';

void main() => runApp(const SifaApp());

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
