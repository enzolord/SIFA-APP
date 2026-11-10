import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Sélecteur de langue Français / English.
class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.instance,
      builder: (context, _) => SegmentedButton<String>(
        showSelectedIcon: false,
        style: compact ? const ButtonStyle(visualDensity: VisualDensity.compact) : null,
        segments: const [
          ButtonSegment(value: 'fr', label: Text('Français')),
          ButtonSegment(value: 'en', label: Text('English')),
        ],
        selected: {L10n.instance.lang},
        onSelectionChanged: (s) => L10n.instance.set(s.first),
      ),
    );
  }
}
