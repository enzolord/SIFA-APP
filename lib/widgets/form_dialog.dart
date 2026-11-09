import 'package:flutter/material.dart';

class FieldSpec {
  const FieldSpec(this.label, {this.number = false, this.hint});
  final String label;
  final bool number;
  final String? hint;
}

/// Petit formulaire modal. Renvoie les valeurs saisies, ou null si annulé.
Future<List<String>?> showFormDialog(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  String confirm = 'Enregistrer',
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _FormDialog(title: title, fields: fields, confirm: confirm),
  );
}

class _FormDialog extends StatefulWidget {
  const _FormDialog({required this.title, required this.fields, required this.confirm});
  final String title, confirm;
  final List<FieldSpec> fields;

  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  late final _ctrls = [for (final _ in widget.fields) TextEditingController()];

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < widget.fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: _ctrls[i],
                keyboardType: widget.fields[i].number
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                decoration: InputDecoration(
                  labelText: widget.fields[i].label,
                  hintText: widget.fields[i].hint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(context, [for (final c in _ctrls) c.text.trim()]),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}

double toNum(String s) => double.tryParse(s.replaceAll(',', '.').replaceAll(' ', '')) ?? 0;
