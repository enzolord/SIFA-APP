import 'package:flutter/material.dart';

import '../services/analysis_store.dart';
import '../widgets/status_chip.dart';
import 'result_screen.dart';
import '../l10n/l10n.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: AnalysisStore.instance,
      builder: (context, _) {
        final items = AnalysisStore.instance.items;
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.history, size: 48),
                const SizedBox(height: 16),
                Tx('Aucune analyse pour le moment', style: t.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Tx('Vos analyses apparaîtront ici.', style: t.bodyMedium, textAlign: TextAlign.center),
              ]),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final d = items[i];
            return Card(
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(d.photo, width: 52, height: 52, fit: BoxFit.cover),
                ),
                title: Tx(d.info.name),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: StatusChip(d.info.status, '${(d.confidence * 100).round()} %'),
                  ),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => ResultScreen(diagnosis: d)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
