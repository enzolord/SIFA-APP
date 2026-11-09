import 'package:flutter/material.dart';

import '../services/analysis_store.dart';
import '../services/session.dart';
import '../widgets/sifa_mark.dart';
import '../widgets/status_chip.dart';
import 'result_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(children: [
          const SifaMark(size: 44),
          const SizedBox(width: 12),
          Text('SIFA', style: t.headlineSmall),
        ]),
        const SizedBox(height: 24),
        Text('Bonjour', style: t.displayMedium),
        const SizedBox(height: 2),
        Text(Session.instance.farmLine, style: t.bodyMedium),
        const SizedBox(height: 4),
        Text('Photographiez une fiente pour vérifier la santé de votre bande.', style: t.bodyLarge),
        const SizedBox(height: 20),
        ListenableBuilder(
          listenable: AnalysisStore.instance,
          builder: (context, _) {
            final d = AnalysisStore.instance.last;
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text('Dernière analyse', style: t.titleMedium),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: d == null
                      ? const Text('Aucune pour le moment. Touchez Scanner pour commencer.')
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: StatusChip(d.info.status, d.info.name),
                        ),
                ),
                trailing: d == null ? null : const Icon(Icons.chevron_right),
                onTap: d == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => ResultScreen(diagnosis: d)),
                        ),
              ),
            );
          },
        ),
      ],
    );
  }
}
