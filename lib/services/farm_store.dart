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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.index,
        'initialCount': initialCount,
        'arrival': arrival.toIso8601String(),
      };

  factory Band.fromJson(Map<String, dynamic> j) => Band(
        id: j['id'] as int,
        name: j['name'] as String,
        type: FlockType.values[j['type'] as int],
        initialCount: j['initialCount'] as int,
        arrival: DateTime.parse(j['arrival'] as String),
      );
}

class DailyEntry {
  DailyEntry({required this.bandId, required this.date, this.dead = 0, this.feedKg = 0, this.waterL = 0, this.avgWeightG});
  final int bandId;
  final DateTime date;
  final int dead;
  final double feedKg;
  final double waterL;
  final double? avgWeightG;

  Map<String, dynamic> toJson() => {
        'bandId': bandId,
        'date': date.toIso8601String(),
        'dead': dead,
        'feedKg': feedKg,
        'waterL': waterL,
        'avgWeightG': avgWeightG,
      };

  factory DailyEntry.fromJson(Map<String, dynamic> j) => DailyEntry(
        bandId: j['bandId'] as int,
        date: DateTime.parse(j['date'] as String),
        dead: j['dead'] as int,
        feedKg: (j['feedKg'] as num).toDouble(),
        waterL: (j['waterL'] as num).toDouble(),
        avgWeightG: (j['avgWeightG'] as num?)?.toDouble(),
      );
}

class StockItem {
  StockItem({required this.name, required this.qty, required this.unit, this.dailyUse = 0});
  final String name;
  double qty;
  final String unit;
  final double dailyUse;

  /// Jours restants si la consommation quotidienne est connue.
  int? get daysLeft => dailyUse > 0 ? (qty / dailyUse).floor() : null;

  Map<String, dynamic> toJson() => {'name': name, 'qty': qty, 'unit': unit, 'dailyUse': dailyUse};

  factory StockItem.fromJson(Map<String, dynamic> j) => StockItem(
        name: j['name'] as String,
        qty: (j['qty'] as num).toDouble(),
        unit: j['unit'] as String,
        dailyUse: (j['dailyUse'] as num).toDouble(),
      );
}

class Txn {
  Txn({required this.date, required this.label, required this.amount, required this.isSale, required this.category});
  final DateTime date;
  final String label;
  final double amount;
  final bool isSale;
  final String category;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'label': label,
        'amount': amount,
        'isSale': isSale,
        'category': category,
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        date: DateTime.parse(j['date'] as String),
        label: j['label'] as String,
        amount: (j['amount'] as num).toDouble(),
        isSale: j['isSale'] as bool,
        category: j['category'] as String,
      );
}

class FarmTask {
  FarmTask({required this.title, required this.due, this.done = false});
  final String title;
  final DateTime due;
  bool done;

  Map<String, dynamic> toJson() => {'title': title, 'due': due.toIso8601String(), 'done': done};

  factory FarmTask.fromJson(Map<String, dynamic> j) => FarmTask(
        title: j['title'] as String,
        due: DateTime.parse(j['due'] as String),
        done: j['done'] as bool,
      );
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

  Map<String, dynamic> toJson() => {
        'bands': [for (final b in bands) b.toJson()],
        'entries': [for (final e in entries) e.toJson()],
        'stock': [for (final x in stock) x.toJson()],
        'txns': [for (final x in txns) x.toJson()],
        'tasks': [for (final x in tasks) x.toJson()],
      };

  List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) f) =>
      [for (final x in (raw as List? ?? const [])) f(Map<String, dynamic>.from(x as Map))];

  void restore(Map<String, dynamic> j) {
    bands..clear()..addAll(_list(j['bands'], Band.fromJson));
    entries..clear()..addAll(_list(j['entries'], DailyEntry.fromJson));
    stock..clear()..addAll(_list(j['stock'], StockItem.fromJson));
    txns..clear()..addAll(_list(j['txns'], Txn.fromJson));
    tasks..clear()..addAll(_list(j['tasks'], FarmTask.fromJson));
    _nextId = bands.fold(0, (m, b) => b.id > m ? b.id : m) + 1;
    notifyListeners();
  }

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
