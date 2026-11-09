import 'package:flutter/foundation.dart';

import 'session.dart';

class Band {
  Band({required this.id, required this.name, required this.type, required this.initialCount, required this.arrival});
  final int id;
  final String name;
  final FlockType type;
  final int initialCount;
  final DateTime arrival;

  int get day => DateTime.now().difference(arrival).inDays + 1;
}

class DailyEntry {
  DailyEntry({required this.bandId, required this.date, this.dead = 0, this.feedKg = 0, this.waterL = 0, this.avgWeightG});
  final int bandId;
  final DateTime date;
  final int dead;
  final double feedKg;
  final double waterL;
  final double? avgWeightG;
}

class StockItem {
  StockItem({required this.name, required this.qty, required this.unit, this.dailyUse = 0});
  final String name;
  double qty;
  final String unit;
  final double dailyUse;

  /// Jours restants si la consommation quotidienne est connue.
  int? get daysLeft => dailyUse > 0 ? (qty / dailyUse).floor() : null;
}

class Txn {
  Txn({required this.date, required this.label, required this.amount, required this.isSale, required this.category});
  final DateTime date;
  final String label;
  final double amount;
  final bool isSale;
  final String category;
}

class FarmTask {
  FarmTask({required this.title, required this.due, this.done = false});
  final String title;
  final DateTime due;
  bool done;
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Gestion de ferme en mémoire (sera remplacée par SQLite local + Supabase).
class FarmStore extends ChangeNotifier {
  FarmStore._();
  static final instance = FarmStore._();

  final List<Band> bands = [];
  final List<DailyEntry> entries = [];
  final List<StockItem> stock = [];
  final List<Txn> txns = [];
  final List<FarmTask> tasks = [];
  int _nextId = 1;

  void addBand(String name, FlockType type, int count, {DateTime? arrival}) {
    bands.add(Band(id: _nextId++, name: name, type: type, initialCount: count, arrival: arrival ?? DateTime.now()));
    notifyListeners();
  }

  void addEntry(DailyEntry e) {
    entries.add(e);
    notifyListeners();
  }

  void addStock(StockItem s) {
    stock.add(s);
    notifyListeners();
  }

  void adjustStock(StockItem s, double delta) {
    s.qty = (s.qty + delta).clamp(0, double.infinity).toDouble();
    notifyListeners();
  }

  void addTxn(Txn t) {
    txns.add(t);
    notifyListeners();
  }

  void addTask(String title, DateTime due) {
    tasks.add(FarmTask(title: title, due: due));
    notifyListeners();
  }

  void toggleTask(FarmTask t) {
    t.done = !t.done;
    notifyListeners();
  }

  // --- Calculs ---
  Iterable<DailyEntry> entriesOf(Band b) => entries.where((e) => e.bandId == b.id);

  int deadTotal(Band b) => entriesOf(b).fold(0, (s, e) => s + e.dead);
  int alive(Band b) => b.initialCount - deadTotal(b);
  double mortalityPct(Band b) => b.initialCount == 0 ? 0 : deadTotal(b) * 100 / b.initialCount;
  double feedTotal(Band b) => entriesOf(b).fold(0.0, (s, e) => s + e.feedKg);

  double? lastWeight(Band b) {
    final w = entriesOf(b).where((e) => e.avgWeightG != null).toList()
      ..sort((a, c) => a.date.compareTo(c.date));
    return w.isEmpty ? null : w.last.avgWeightG;
  }

  int get totalAlive => bands.fold(0, (s, b) => s + alive(b));
  int get totalPlaced => bands.fold(0, (s, b) => s + b.initialCount);

  /// Mortalité des 7 derniers jours, en % de l'effectif placé.
  double get mortality7d {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final dead = entries.where((e) => e.date.isAfter(since)).fold(0, (s, e) => s + e.dead);
    return totalPlaced == 0 ? 0 : dead * 100 / totalPlaced;
  }

  double get feedToday {
    final now = DateTime.now();
    return entries.where((e) => _sameDay(e.date, now)).fold(0.0, (s, e) => s + e.feedKg);
  }

  Iterable<Txn> get monthTxns {
    final n = DateTime.now();
    return txns.where((t) => t.date.year == n.year && t.date.month == n.month);
  }

  double get monthSales => monthTxns.where((t) => t.isSale).fold(0.0, (s, t) => s + t.amount);
  double get monthExpenses => monthTxns.where((t) => !t.isSale).fold(0.0, (s, t) => s + t.amount);
  double get monthMargin => monthSales - monthExpenses;

  Map<String, double> get expensesByCategory {
    final m = <String, double>{};
    for (final t in monthTxns.where((t) => !t.isSale)) {
      m[t.category] = (m[t.category] ?? 0) + t.amount;
    }
    return m;
  }

  int get todayEntriesCount {
    final now = DateTime.now();
    return bands.where((b) => entries.any((e) => e.bandId == b.id && _sameDay(e.date, now))).length;
  }
}

String fcfa(double v) {
  final s = v.round().abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$buf';
}
