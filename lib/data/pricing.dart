/// Tarifs SIFA : trois formules (analyse, gestion de ferme, pack complet).
///
/// Les prix ci-dessous sont ceux de la grille officielle. L'administration peut les corriger
/// sans mise à jour de l'application : section distante `tarifs` (voir [Pricing.fromRemote]).
class AnalysisPack {
  const AnalysisPack(this.key, this.name, this.accounts, this.analyses, this.price, {this.accountsAndMore = false});

  /// Identifiant court (solo, equipe, pro, entreprise).
  final String key;
  final String name;
  final int accounts;
  final int analyses;
  final int price; // FCFA par mois
  final bool accountsAndMore;

  String get id => 'analyse_$key';
  int get pricePerAnalysis => (price / analyses).round();
}

class FarmTier {
  const FarmTier(this.n, this.min, this.max, this.price);

  final int n;
  final int min;
  final int? max; // null = sans limite
  final int? price; // FCFA par mois ; null = sur devis

  String get id => 'gestion_$n';
  String get name => 'Gestion $n';
  bool get onQuote => price == null;
}

/// Une combinaison analyse + gestion, avec la réduction du pack complet.
class PackDeal {
  const PackDeal(this.analysis, this.tier, this.sum, this.price);

  final AnalysisPack analysis;
  final FarmTier tier;
  final int sum;
  final int price;

  String get id => 'pack_${analysis.key}_${tier.n}';
  int get saving => sum - price;
}

class Pricing {
  const Pricing({
    required this.packs,
    required this.tiers,
    this.extraAccount = 500,
    this.extraAnalyses = 1000,
    this.extraAnalysesCount = 20,
    this.packDiscount = 15,
    this.farmAccounts = 2,
    this.farmManagementAvailable = false,
  });

  final List<AnalysisPack> packs;
  final List<FarmTier> tiers;

  /// Option : un compte de plus, par mois.
  final int extraAccount;

  /// Option : [extraAnalysesCount] analyses de plus, pour ce prix.
  final int extraAnalyses;
  final int extraAnalysesCount;

  /// Réduction du pack complet, en pourcent.
  final int packDiscount;

  /// Comptes inclus dans la formule Gestion de ferme.
  final int farmAccounts;

  /// La gestion de ferme n'est proposée à l'achat que lorsque l'administration l'active.
  final bool farmManagementAvailable;

  static const defaults = Pricing(
    packs: [
      AnalysisPack('solo', 'Analyse SOLO', 1, 20, 2000),
      AnalysisPack('equipe', 'Analyse ÉQUIPE', 3, 60, 4500),
      AnalysisPack('pro', 'Analyse PRO', 10, 200, 12000),
      AnalysisPack('entreprise', 'Analyse ENTREPRISE', 25, 600, 30000, accountsAndMore: true),
    ],
    tiers: [
      FarmTier(1, 200, 500, 5000),
      FarmTier(2, 501, 1500, 6000),
      FarmTier(3, 1501, 3500, 8000),
      FarmTier(4, 3501, 6500, 11000),
      FarmTier(5, 6501, 10500, 15000),
      FarmTier(6, 10501, 20500, 22000),
      FarmTier(7, 20501, null, null),
    ],
  );

  /// Combinaisons mises en avant dans la grille officielle.
  static const featured = [('solo', 1), ('solo', 2), ('equipe', 3), ('pro', 4), ('entreprise', 6)];

  /// Applique les corrections de l'administration : `{"prix": {"analyse_solo": 2000, "gestion_7": null},
  /// "reduction_pack": 15, "gestion_disponible": true, ...}`. Toute valeur absente ou invalide garde le défaut.
  factory Pricing.fromRemote(Map<String, dynamic> j) {
    final prix = j['prix'] is Map ? Map<String, dynamic>.from(j['prix'] as Map) : const <String, dynamic>{};
    int? price(String id, int? fallback) {
      if (!prix.containsKey(id)) return fallback;
      final v = prix[id];
      if (v == null) return null;
      return v is num && v > 0 ? v.round() : fallback;
    }

    int num_(String key, int fallback, {int min = 0, int max = 10000000}) {
      final v = j[key];
      return v is num && v >= min && v <= max ? v.round() : fallback;
    }

    final d = defaults;
    return Pricing(
      packs: [
        for (final p in d.packs) AnalysisPack(p.key, p.name, p.accounts, p.analyses, price(p.id, p.price) ?? p.price, accountsAndMore: p.accountsAndMore),
      ],
      tiers: [for (final t in d.tiers) FarmTier(t.n, t.min, t.max, price(t.id, t.price))],
      extraAccount: num_('compte_supplementaire', d.extraAccount, min: 1),
      extraAnalyses: num_('analyses_supplementaires', d.extraAnalyses, min: 1),
      packDiscount: num_('reduction_pack', d.packDiscount, max: 90),
      farmManagementAvailable: j['gestion_disponible'] == true,
    );
  }

  /// Prix du pack complet : somme des deux formules, moins la réduction, arrondi à 50 FCFA au-dessus.
  PackDeal? deal(AnalysisPack a, FarmTier t) {
    final tp = t.price;
    if (tp == null) return null;
    final sum = a.price + tp;
    final raw = sum * (100 - packDiscount) / 100;
    final price = (raw / 50).ceil() * 50;
    return PackDeal(a, t, sum, price);
  }

  AnalysisPack packByKey(String key) => packs.firstWhere((p) => p.key == key);
  FarmTier tier(int n) => tiers.firstWhere((t) => t.n == n);

  /// Identifiant d'offre -> (libellé, prix par mois). Null si l'identifiant est inconnu.
  (String, int?)? lookup(String id) {
    for (final p in packs) {
      if (p.id == id) return (p.name, p.price);
    }
    for (final t in tiers) {
      if (t.id == id) return (t.name, t.price);
    }
    final m = RegExp(r'^pack_([a-z]+)_(\d)$').firstMatch(id);
    if (m != null) {
      final a = packs.where((p) => p.key == m[1]);
      final t = tiers.where((x) => x.n == int.parse(m[2]!));
      if (a.isNotEmpty && t.isNotEmpty) {
        final d = deal(a.first, t.first);
        return ('Pack ${a.first.name.replaceFirst('Analyse ', '')} + ${t.first.name}', d?.price);
      }
    }
    return null;
  }
}

/// 12500 -> « 12 500 FCFA » (espace insécable fine).
String fcfa(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '$b FCFA';
}
