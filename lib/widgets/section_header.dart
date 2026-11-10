import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Row(children: [
        Expanded(child: Text(title, style: t.titleLarge)),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ]),
    );
  }
}
