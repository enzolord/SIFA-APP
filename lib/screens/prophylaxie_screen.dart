import 'package:flutter/material.dart';

import '../services/session.dart';
import '../widgets/disclaimer.dart';
import '../widgets/status_chip.dart';
import '../l10n/l10n.dart';

class _Step {
  const _Step(this.day, this.title, this.status, this.label);
  final int day;
  final String title;
  final SifaStatus status;
  final String label;
}

/// Calendrier type donné à titre d'exemple (à valider avec un vétérinaire).
const _plan = [
  (1, 'Newcastle + bronchite infectieuse'),
  (14, 'Gumboro (1re dose)'),
  (21, 'Gumboro (2e dose)'),
  (28, 'Rappel Newcastle'),
];

class ProphylaxieScreen extends StatelessWidget {
  const ProphylaxieScreen({super.key, this.currentDay = 12});

  /// Jour du lot (démo : 12). Sera calculé depuis la date d'arrivée de la bande.
  final int currentDay;

  _Step _step((int, String) e) {
    final (day, title) = e;
    if (day < currentDay) return _Step(day, title, SifaStatus.ok, 'Fait');
    final delta = day - currentDay;
    if (delta <= 3) return _Step(day, title, SifaStatus.warn, 'À préparer');
    return _Step(day, title, SifaStatus.neutral, 'À venir');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Tx('Calendrier de vaccination')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Tx(trf('{0} · jour {1}', [tr(Session.instance.flockType.label), currentDay]), style: t.titleMedium),
          const SizedBox(height: 16),
          for (final e in _plan) ...[
            Builder(builder: (context) {
              final s = _step(e);
              final delta = s.day - currentDay;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Tx(
                      delta > 0 ? trf(delta > 1 ? 'Jour {0} · dans {1} jours' : 'Jour {0} · dans {1} jour', [s.day, delta]) : trf('Jour {0}', [s.day]),
                      style: t.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Tx(s.title, style: t.titleMedium),
                    const SizedBox(height: 10),
                    StatusChip(s.status, s.label),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
          const Disclaimer(),
          const SizedBox(height: 8),
          Tx(
            'Calendrier type donné à titre d\'exemple. Adaptez-le avec votre vétérinaire selon votre zone et les maladies présentes.',
            style: t.bodyMedium,
          ),
        ],
      ),
    );
  }
}
