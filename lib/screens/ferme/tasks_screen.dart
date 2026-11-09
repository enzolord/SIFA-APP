import 'package:flutter/material.dart';

import '../../services/farm_store.dart';
import '../../widgets/form_dialog.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final v = await showFormDialog(context, title: 'Ajouter une tâche', fields: const [
      FieldSpec('Tâche', hint: 'Nettoyer les abreuvoirs'),
      FieldSpec('Dans combien de jours ?', number: true, hint: '0 = aujourd\'hui'),
    ]);
    if (v == null || v[0].isEmpty) return;
    FarmStore.instance.addTask(v[0], DateTime.now().add(Duration(days: toNum(v[1]).round())));
  }

  String _when(DateTime d) {
    final n = DateTime.now();
    final days = DateTime(d.year, d.month, d.day).difference(DateTime(n.year, n.month, n.day)).inDays;
    if (days <= 0) return "Aujourd'hui";
    if (days == 1) return 'Demain';
    return 'Dans $days jours';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FarmStore.instance,
      builder: (context, _) {
        final tasks = [...FarmStore.instance.tasks]..sort((a, b) {
            if (a.done != b.done) return a.done ? 1 : -1;
            return a.due.compareTo(b.due);
          });
        return Scaffold(
          appBar: AppBar(title: const Text('Tâches')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une tâche'),
          ),
          body: tasks.isEmpty
              ? const Center(child: Text('Aucune tâche.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                  children: [
                    for (final t in tasks)
                      CheckboxListTile(
                        value: t.done,
                        onChanged: (_) => FarmStore.instance.toggleTask(t),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(t.title, style: TextStyle(decoration: t.done ? TextDecoration.lineThrough : null)),
                        subtitle: Text(_when(t.due)),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
