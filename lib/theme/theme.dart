import 'package:flutter/material.dart';

import 'colors.dart';

TextTheme _text(Color ink) => TextTheme(
      displayMedium: TextStyle(fontFamily: 'BricolageGrotesque', fontSize: 32, height: 1.125, fontWeight: FontWeight.w700, color: ink),
      headlineSmall: TextStyle(fontFamily: 'BricolageGrotesque', fontSize: 24, height: 1.25, fontWeight: FontWeight.w600, color: ink),
      headlineMedium: TextStyle(fontFamily: 'BricolageGrotesque', fontSize: 28, height: 1.2, fontWeight: FontWeight.w700, color: ink),
      titleLarge: TextStyle(fontFamily: 'BricolageGrotesque', fontSize: 20, height: 1.3, fontWeight: FontWeight.w600, color: ink),
      titleMedium: TextStyle(fontSize: 18, height: 1.45, fontWeight: FontWeight.w600, color: ink),
      titleSmall: TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w600, color: ink),
      bodySmall: TextStyle(fontSize: 13, height: 1.4, color: ink.withValues(alpha: 0.72)),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.43, color: ink),
      labelLarge: TextStyle(fontSize: 13, height: 1.23, fontWeight: FontWeight.w600, letterSpacing: 0.26, color: ink),
    );

ThemeData _build(ColorScheme scheme, Color raised) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'Figtree',
    textTheme: _text(scheme.onSurface),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: _text(scheme.onSurface).headlineSmall,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: raised,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.09)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: raised,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: 0.2)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: raised,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      height: 68,
    ),
  );
}

ThemeData sifaLightTheme() => _build(
      const ColorScheme(
        brightness: Brightness.light,
        primary: SifaColors.brand,
        onPrimary: Colors.white,
        secondary: SifaColors.yolk,
        onSecondary: SifaColors.onYolk,
        error: SifaColors.danger,
        onError: Colors.white,
        surface: SifaColors.surface,
        onSurface: SifaColors.ink,
      ),
      SifaColors.surfaceRaised,
    );

ThemeData sifaDarkTheme() => _build(
      const ColorScheme(
        brightness: Brightness.dark,
        primary: SifaColors.darkBrand,
        onPrimary: SifaColors.darkOnBrand,
        secondary: SifaColors.yolk,
        onSecondary: SifaColors.onYolk,
        error: Color(0xFFFF8A75),
        onError: Color(0xFF3A0A00),
        surface: SifaColors.darkSurface,
        onSurface: SifaColors.darkInk,
      ),
      SifaColors.darkRaised,
    );
