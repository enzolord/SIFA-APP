import 'package:flutter/material.dart';

import '../theme/colors.dart';

enum SifaStatus { ok, warn, danger }

/// Puce de gravité : icône + libellé, jamais la couleur seule.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, this.label, {super.key});
  final SifaStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon) = switch (status) {
      SifaStatus.ok => (SifaColors.ok, SifaColors.okSoft, Icons.check_circle),
      SifaStatus.warn => (SifaColors.warn, SifaColors.warnSoft, Icons.error),
      SifaStatus.danger => (SifaColors.danger, SifaColors.dangerSoft, Icons.warning_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: fg),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}
