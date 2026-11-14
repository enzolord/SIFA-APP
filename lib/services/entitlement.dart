import 'package:flutter/foundation.dart';

import '../data/pricing.dart';
import 'auth_service.dart';
import 'remote_content.dart';

/// Ce que l'abonnement de l'éleveur donne droit de faire : analyses (quota) et gestion de ferme.
///
/// Sans abonnement d'analyse, le compte a [Pricing.freeAnalyses] analyses offertes (5 par défaut),
/// une fois pour toutes ; ensuite les analyses sont bloquées. Avec une formule d'analyse, le quota
/// du pack s'applique par période de 30 jours à partir de l'activation.
///
/// Le compteur est gardé sur le téléphone. Il n'est pas protégé contre une réinstallation de l'application.
class Entitlement extends ChangeNotifier {
  Entitlement._();
  static final instance = Entitlement._();

  /// Remplaçable dans les tests.
  Pricing Function() pricing = () => Pricing.fromRemote(RemoteContent.instance.section('tarifs'));
  DateTime Function() now = DateTime.now;

  int _freeUsed = 0;
  int _paidUsed = 0;
  int _paidWindow = 0;
  String? _offer;
  DateTime? _since;
  DateTime? _until;

  String? get _activeOffer => (_offer != null && (_until == null || _until!.isAfter(now()))) ? _offer : null;

  /// Identifiant de l'offre active (analyse_pro, gestion_3, pack_pro_4, mensuelle...), ou null.
  String? get offerId => _activeOffer;
  DateTime? get until => _activeOffer == null ? null : _until;

  /// Le plan donne un quota d'analyses propre (null = illimité, pour les anciennes formules).
  bool get hasAnalysisPlan => _analysisAllowance != -1;

  /// -1 : pas de plan d'analyse ; 0 : illimité ; sinon nombre d'analyses par période.
  int get _analysisAllowance {
    final id = _activeOffer;
    if (id == null) return -1;
    if (id == 'mensuelle' || id == 'annuelle' || id == 'promo_analyse' || id == 'promo_complet') return 0;
    final p = pricing();
    String? key;
    if (id.startsWith('analyse_')) {
      key = id.substring(8);
    } else {
      final m = RegExp(r'^pack_([a-z]+)_\d$').firstMatch(id);
      key = m?[1];
    }
    if (key == null) return -1;
    final pack = p.packs.where((x) => x.key == key);
    return pack.isEmpty ? -1 : pack.first.analyses;
  }

  int get _window => _since == null ? 0 : now().difference(_since!).inDays ~/ 30;

  /// Nombre d'analyses autorisées (null = illimité).
  int? get limit {
    final a = _analysisAllowance;
    if (a == -1) return pricing().freeAnalyses;
    return a == 0 ? null : a;
  }

  int get used {
    if (_analysisAllowance == -1) return _freeUsed;
    return _paidWindow == _window ? _paidUsed : 0;
  }

  int? get remaining {
    final l = limit;
    return l == null ? null : (l - used).clamp(0, l);
  }

  bool get canAnalyze => remaining == null || remaining! > 0;

  /// Vrai si la période gratuite est la seule en cours (aucun plan d'analyse).
  bool get isFree => _analysisAllowance == -1;

  void recordAnalysis() {
    if (_analysisAllowance == -1) {
      _freeUsed++;
    } else {
      if (_paidWindow != _window) {
        _paidWindow = _window;
        _paidUsed = 0;
      }
      _paidUsed++;
    }
    notifyListeners();
  }

  /// Gestion de ferme : ouverte à tous tant que l'administration ne l'a pas mise en vente ;
  /// ensuite réservée aux formules Gestion, Pack complet et aux codes d'accès gestion ou complet.
  bool get farmAccess {
    if (!pricing().farmManagementAvailable) return true;
    final id = _activeOffer;
    return id != null && (id.startsWith('gestion_') || id.startsWith('pack_') || id == 'promo_gestion' || id == 'promo_complet');
  }

  /// Niveau de gestion de l'abonnement (1 à 7), null sans formule de gestion.
  int? get farmTier {
    final id = _activeOffer;
    if (id == null) return null;
    final m = RegExp(r'^(?:gestion_|pack_[a-z]+_)(\d)$').firstMatch(id);
    return m == null ? null : int.parse(m[1]!);
  }

  /// Interroge le serveur (fonction mon_abonnement) pour connaître l'offre active.
  Future<void> refresh() async {
    final auth = AuthService.instance;
    final c = auth.client;
    if (c == null) return;
    if (!auth.signedIn) {
      if (_offer != null) {
        _offer = null;
        _since = _until = null;
        notifyListeners();
      }
      return;
    }
    try {
      final rows = await c.rpc('mon_abonnement');
      final list = rows is List ? rows : const [];
      if (list.isEmpty) {
        _offer = null;
        _since = _until = null;
      } else {
        final r = Map<String, dynamic>.from(list.first as Map);
        final since = DateTime.tryParse('${r['debut']}')?.toLocal();
        if (since != _since) {
          _paidUsed = 0;
          _paidWindow = 0;
        }
        _offer = r['formule'] as String?;
        _since = since;
        _until = r['fin'] == null ? null : DateTime.tryParse('${r['fin']}')?.toLocal();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Abonnement : $e'); // hors connexion : on garde l'offre mémorisée
    }
  }

  void start() => AuthService.instance.addListener(refresh);

  Map<String, dynamic> toJson() => {
        'freeUsed': _freeUsed,
        'paidUsed': _paidUsed,
        'paidWindow': _paidWindow,
        'offer': _offer,
        'since': _since?.toIso8601String(),
        'until': _until?.toIso8601String(),
      };

  void restore(Map<String, dynamic> j) {
    _freeUsed = j['freeUsed'] as int? ?? 0;
    _paidUsed = j['paidUsed'] as int? ?? 0;
    _paidWindow = j['paidWindow'] as int? ?? 0;
    _offer = j['offer'] as String?;
    _since = DateTime.tryParse('${j['since']}');
    _until = DateTime.tryParse('${j['until']}');
    notifyListeners();
  }

  @visibleForTesting
  void debugReset({String? offer, DateTime? since, DateTime? until, int freeUsed = 0, int paidUsed = 0}) {
    _offer = offer;
    _since = since;
    _until = until;
    _freeUsed = freeUsed;
    _paidUsed = paidUsed;
    _paidWindow = 0;
  }
}
