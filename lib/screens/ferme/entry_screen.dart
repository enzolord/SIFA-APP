import 'package:flutter/material.dart';

import '../../services/farm_store.dart';
import '../../widgets/form_dialog.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key, this.initialBand});
  final Band? initialBand;

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  Band? _band;
  final _dead = TextEditingController();
  final _feed = TextEditingController();
  final _water = TextEditingController();
  final _weight = TextEditingController();

  @override
  void initState() {
    super.initState();
    final bands = FarmStore.instance.bands;
    _band = widget.initialBand ?? (bands.isEmpty ? null : bands.first);
  }

  @override
  void dispose() {
    for (final c in [_dead, _feed, _water, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final b = _band;
    if (b == null) return;
    FarmStore.instance.addEntry(DailyEntry(
      bandId: b.id,
      date: DateTime.now(),
      dead: toNum(_dead.text).round(),
      feedKg: toNum(_feed.text),
      waterL: toNum(_water.text),
      avgWeightG: _weight.text.trim().isEmpty ? null : toNum(_weight.text),
    ));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Journée enregistrée.')));
    Navigator.of(context).pop();
  }

  Widget _field(String label, TextEditingController c, String unit) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, suffixText: unit, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bands = FarmStore.instance.bands;
    return Scaffold(
      appBar: AppBar(title: const Text('Saisie du jour')),
      body: bands.isEmpty
          ? const Center(child: Text("Ajoutez d'abord une bande."))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                DropdownButtonFormField<Band>(
                  initialValue: _band,
                  decoration: const InputDecoration(labelText: 'Bande', border: OutlineInputBorder()),
                  items: [for (final b in bands) DropdownMenuItem(value: b, child: Text('${b.name} · jour ${b.day}'))],
                  onChanged: (b) => setState(() => _band = b),
                ),
                const SizedBox(height: 16),
                _field('Oiseaux morts', _dead, 'oiseaux'),
                _field('Aliment distribué', _feed, 'kg'),
                _field('Eau consommée', _water, 'litres'),
                _field("Poids moyen (pesée d'un échantillon)", _weight, 'g'),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                  onPressed: _save,
                  child: const Text('Enregistrer la journée'),
                ),
              ],
            ),
    );
  }
}
