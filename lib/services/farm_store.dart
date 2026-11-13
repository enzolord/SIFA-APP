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
  DailyEntry({required this.bandId, required this.date, this.dead = 0, this.feedKg = 0, this.waterL = 0, this.avgWeightG, this.eggs, this.cracked});
  final int bandId;
  final DateTime date;
  final int dead;
  final double feedKg;
  final double waterL;
  final double? avgWeightG;

  /// Pondeuses : œufs ramassés ce jour-là, dont cassés ou déclassés.
  final int? eggs;
  final int? cracked;

  Map<String, dynamic> toJson() => {
        'bandId': bandId,
        'date': date.toIso8601String(),
        'dead': dead,
        'feedKg': feedKg,
        'waterL': waterL,
        'avgWeightG': avgWeightG,
        'eggs': eggs,
        'cracked': cracked,
      };

  factory DailyEntry.fromJson(Map<String, dynamic> j) => DailyEntry(
        bandId: j['bandId'] as int,
        date: DateTime.parse(j['date'] as String),
        dead: j['dead'] as int,
        feedKg: (j['feedKg'] as num).toDouble(),
        waterL: (j['waterL'] as num).toDouble(),
        avgWeightG: (j['avgWeightG'] as num?)?.toDouble(),
        eggs: (j['eggs'] as num?)?.round(),
        cracked: (j['cracked'] as num?)?.round(),
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
  Txn({required this.date, required this.label, required this.amount, required this.isSale, required this.category, this.bandId, this.client});
  final DateTime date;
  final String label;
  final double amount;
  final bool isSale;
  final String category;

  /// Bande concernée (pour la rentabilité par bande) et client acheteur, s'ils sont connus.
  final int? bandId;
  final String? client;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'label': label,
        'amount': amount,
        'isSale': isSale,
        'category': category,
        'bandId': bandId,
        'client': client,
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        date: DateTime.parse(j['date'] as String),
        label: j['label'] as String,
        amount: (j['amount'] as num).toDouble(),
        isSale: j['isSale'] as bool,
        category: j['category'] as String,
        bandId: j['bandId'] as int?,
        client: j['client'] as String?,
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

class Client {
  Client({required this.name, this.phone = ''});
  final String name;
  final String phone;

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};
  factory Client.fromJson(Map<String, dynamic> j) => Client(name: j['name'] as String, phone: j['phone'] as String? ?? '');
}

enum HealthKind { vaccine, treatment, other }

/// Vaccin, traitement ou autre soin donné à une bande, avec son délai d'attente
/// (jours pendant lesquels on ne vend ni œufs ni poulets après un médicament).
class HealthEvent {
  HealthEvent({required this.bandId, required this.date, required this.kind, required this.product, this.note = '', this.withdrawalDays = 0});
  final int bandId;
  final DateTime date;
  final HealthKind kind;
  final String product;
  final String note;
  final int withdrawalDays;

  DateTime get withdrawalEnd => DateTime(date.year, date.month, date.day).add(Duration(days: withdrawalDays));
  bool get inWithdrawal => withdrawalDays > 0 && withdrawalEnd.isAfter(DateTime.now());

  Map<String, dynamic> toJson() => {
        'bandId': bandId,
        'date': date.toIso8601String(),
        'kind': kind.index,
        'product': product,
        'note': note,
        'withdrawalDays': withdrawalDays,
      };

  factory HealthEvent.fromJson(Map<String, dynamic> j) => HealthEvent(
        bandId: j['bandId'] as int,
        date: DateTime.parse(j['date'] as String),
        kind: HealthKind.values[(j['kind'] as int? ?? 2).clamp(0, HealthKind.values.length - 1)],
        product: j['product'] as String? ?? '',
        note: j['note'] as String? ?? '',
        withdrawalDays: j['withdrawalDays'] as int? ?? 0,
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
  final List<HealthEvent> health = [];
  final List<Client> clients = [];
  int _nextId = 1;

  Map<String, dynamic> toJson() => {
        'bands': [for (final b in bands) b.toJson()],
        'entries': [for (final e in entries) e.toJson()],
        'stock': [for (final x in stock) x.toJson()],
        'txns': [for (final x in txns) x.toJson()],
        'tasks': [for (final x in tasks) x.toJson()],
        'health': [for (final x in health) x.toJson()],
        'clients': [for (final x in clients) x.toJson()],
      };

  List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) f) =>
      [for (final x in (raw as List? ?? const [])) f(Map<String, dynamic>.from(x as Map))];

  void restore(Map<String, dynamic> j) {
    bands..clear()..addAll(_list(j['bands'], Band.fromJson));
    entries..clear()..addAll(_list(j['entries'], DailyEntry.fromJson));
    stock..clear()..addAll(_list(j['stock'], StockItem.fromJson));
    txns..clear()..addAll(_list(j['txns'], Txn.fromJson));
    tasks..clear()..addAll(_list(j['tasks'], FarmTask.fromJson));
    health..clear()..addAll(_list(j['health'], HealthEvent.fromJson));
    clients..clear()..addAll(_list(j['clients'], Client.fromJson));
    _nextId = bands.fold(0, (m, b) => b.id > m ? b.id : m) + 1;
    notifyListeners();
  }

  /// Crée une bande. Si [chickCost] est donné, le prix d'achat des poussins est noté en dépense de cette bande.
  Band addBand(String name, FlockType type, int count, {DateTime? arrival, double chickCost = 0}) {
    final b = Band(id: _nextId++, name: name, type: type, initialCount: count, arrival: arrival ?? DateTime.now());
    bands.add(b);
    if (chickCost > 0) {
      txns.add(Txn(date: b.arrival, label: 'Achat des poussins', amount: chickCost, isSale: false, category: 'Poussins', bandId: b.id));
    }
    notifyListeners();
    return b;
  }

  void addClient(Client c) {
    if (clients.any((x) => x.name.toLowerCase() == c.name.toLowerCase())) return;
    clients.add(c);
    notifyListeners();
  }

  void removeClient(Client c) {
    clients.remove(c);
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

  void addHealth(HealthEvent e) {
    health.add(e);
    notifyListeners();
  }

  void removeHealth(HealthEvent e) {
    health.remove(e);
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

  /// Taux de ponte des [days] derniers jours : œufs ramassés / (poules vivantes x jours saisis). Null sans saisie d'œufs.
  double? layingRate(Band b, {int days = 7}) {
    final since = DateTime.now().subtract(Duration(days: days));
    final es = entriesOf(b).where((e) => e.eggs != null && e.date.isAfter(since)).toList();
    final hens = alive(b);
    if (es.isEmpty || hens <= 0) return null;
    final eggs = es.fold(0, (s, e) => s + e.eggs!);
    return eggs * 100 / (hens * es.length);
  }

  int eggsToday(Band b) => entriesOf(b).where((e) => _sameDay(e.date, DateTime.now())).fold(0, (s, e) => s + (e.eggs ?? 0));

  /// Indice de consommation approximatif : aliment distribué / poids vif des poulets vivants (dernière pesée).
  /// Plus il est bas, mieux c'est. Null sans pesée ni aliment saisis.
  double? feedConversion(Band b) {
    final w = lastWeight(b);
    final kg = feedTotal(b);
    final n = alive(b);
    if (w == null || w <= 0 || kg <= 0 || n <= 0) return null;
    return kg / (n * w / 1000);
  }

  /// Aliment par poulet et par jour, en grammes, sur les jours saisis.
  double? feedPerBirdG(Band b) {
    final es = entriesOf(b).where((e) => e.feedKg > 0).toList();
    final n = alive(b);
    if (es.isEmpty || n <= 0) return null;
    return es.fold(0.0, (s, e) => s + e.feedKg) * 1000 / (n * es.length);
  }

  Iterable<HealthEvent> get activeWithdrawals => health.where((h) => h.inWithdrawal);
  List<HealthEvent> healthOf(Band b) => health.where((h) => h.bandId == b.id).toList()..sort((a, c) => c.date.compareTo(a.date));

  // --- Rentabilité par bande ---
  Iterable<Txn> txnsOf(Band b) => txns.where((t) => t.bandId == b.id);
  double salesOf(Band b) => txnsOf(b).where((t) => t.isSale).fold(0.0, (s, t) => s + t.amount);
  double expensesOf(Band b) => txnsOf(b).where((t) => !t.isSale).fold(0.0, (s, t) => s + t.amount);
  double profitOf(Band b) => salesOf(b) - expensesOf(b);

  /// Marge par oiseau encore vivant. Null s'il n'en reste aucun.
  double? profitPerBird(Band b) => alive(b) > 0 ? profitOf(b) / alive(b) : null;

  /// Ventes et dépenses non rattachées à une bande.
  double get unassignedSales => txns.where((t) => t.bandId == null && t.isSale).fold(0.0, (s, t) => s + t.amount);
  double get unassignedExpenses => txns.where((t) => t.bandId == null && !t.isSale).fold(0.0, (s, t) => s + t.amount);

  // --- Clients ---
  Iterable<Txn> salesTo(String name) => txns.where((t) => t.isSale && (t.client ?? '').toLowerCase() == name.toLowerCase());
  double totalBoughtBy(String name) => salesTo(name).fold(0.0, (s, t) => s + t.amount);

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
