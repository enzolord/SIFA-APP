import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../l10n/l10n.dart';

class Disclaimer extends StatelessWidget {
  const Disclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SifaColors.yolkSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, color: SifaColors.ink, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Tx(
            "SIFA aide à repérer un problème, il ne remplace pas un vétérinaire. En cas de doute, appelez votre vétérinaire.",
            style: TextStyle(color: SifaColors.ink, fontSize: 14, height: 1.4),
          ),
        ),
      ]),
    );
  }
}
