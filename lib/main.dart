import 'package:flutter/material.dart';

import 'screens/shell.dart';
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
      home: const Shell(),
    );
  }
}
