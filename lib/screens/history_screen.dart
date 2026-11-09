import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => const _Empty(
        icon: Icons.history,
        title: 'Aucune analyse pour le moment',
        body: 'Vos analyses apparaîtront ici, classées par bande.',
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title, body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48),
          const SizedBox(height: 16),
          Text(title, style: t.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(body, style: t.bodyMedium, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
