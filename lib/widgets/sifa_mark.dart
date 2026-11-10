import 'package:flutter/material.dart';

/// Symbole SIFA en 3D (viseur + fiente + ECG), sans fond.
/// [onDark] : angles blancs pour les fonds sombres ou colorés.
class SifaMark extends StatelessWidget {
  const SifaMark({super.key, this.size = 96, this.onDark = false});
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Image.asset(
        onDark ? 'assets/brand/logo_sombre.png' : 'assets/brand/logo_clair.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Logo SIFA',
      );
}

/// Icône SIFA complète (carré vert arrondi), pour les en-têtes.
class SifaIcon extends StatelessWidget {
  const SifaIcon({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/brand/icone.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'SIFA',
      );
}
