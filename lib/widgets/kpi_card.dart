import 'package:flutter/material.dart';

import '../theme/colors.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.label, required this.value, this.sub, this.subColor});
  final String label, value;
  final String? sub;
  final Color? subColor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: t.bodyMedium?.copyWith(color: SifaColors.inkMuted)),
          const SizedBox(height: 4),
          Text(value, style: t.headlineSmall),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!, style: t.bodyMedium?.copyWith(color: subColor, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ]),
      ),
    );
  }
}
