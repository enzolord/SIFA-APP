import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Barre de navigation : 4 onglets + bouton Scanner surélevé au centre (action principale de l'app).
class SifaNavBar extends StatelessWidget {
  const SifaNavBar({super.key, required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  static const _barH = 64.0;
  static const _lift = 26.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raised = theme.navigationBarTheme.backgroundColor ?? theme.colorScheme.surface;
    final bottom = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      height: _barH + _lift + bottom,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _barH + bottom,
          child: Material(
            color: raised,
            elevation: 12,
            shadowColor: Colors.black,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: Row(children: [
                _Item(0, index, 'Accueil', Icons.home_outlined, Icons.home_rounded, onSelect),
                _Item(1, index, 'Historique', Icons.history_rounded, Icons.history_rounded, onSelect),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Scanner',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                _Item(3, index, 'Communauté', Icons.groups_outlined, Icons.groups_rounded, onSelect),
                _Item(4, index, 'Profil', Icons.person_outline_rounded, Icons.person_rounded, onSelect),
              ]),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: _ScanButton(
              selected: index == 2,
              ring: raised,
              onTap: () => onSelect(2),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.i, this.current, this.label, this.icon, this.activeIcon, this.onSelect);
  final int i, current;
  final String label;
  final IconData icon, activeIcon;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final on = i == current;
    final color = on ? cs.primary : cs.onSurface.withValues(alpha: 0.62);
    return Expanded(
      child: Semantics(
        button: true,
        selected: on,
        label: label,
        child: InkWell(
          onTap: () => onSelect(i),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              decoration: BoxDecoration(
                color: on ? cs.primary.withValues(alpha: 0.14) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(on ? activeIcon : icon, size: 24, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: color),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.selected, required this.ring, required this.onTap});
  final bool selected;
  final Color ring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Scanner une fiente',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1.06 : 1,
          duration: const Duration(milliseconds: 180),
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 5),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E9A72), SifaColors.brand, Color(0xFF083D2E)],
              ),
              boxShadow: [
                BoxShadow(
                  color: SifaColors.brand.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.center_focus_strong_rounded, color: Colors.white, size: 34),
          ),
        ),
      ),
    );
  }
}
