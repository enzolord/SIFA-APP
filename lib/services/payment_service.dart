import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

class PaymentException implements Exception {
  PaymentException(this.message);
  final String message; // en français, à passer par tr() à l'affichage
  @override
  String toString() => message;
}

class PaymentStart {
  PaymentStart({required this.id, required this.status, required this.amount, this.ussd, this.operator});
  final String id;
  final String status; // en_attente ou reussi (réduction de 100 %)
  final int amount;
  final String? ussd;
  final String? operator;
}

/// Paiement Mobile Money (MTN, Orange) par Campay, via la fonction Supabase `campay-paiement`.
/// Le montant n'est jamais envoyé par l'application : le serveur le recalcule à partir de l'offre.
class PaymentService {
  static Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    final c = AuthService.instance.client;
    if (c == null || !AuthService.instance.signedIn) throw PaymentException('Connectez-vous avec Google (onglet Profil) pour payer.');
    try {
      final r = await c.functions.invoke('campay-paiement', body: body);
      final d = r.data;
      return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = d is Map && d['erreur'] is String ? d['erreur'] as String : 'Le paiement a échoué. Réessayez.';
      throw PaymentException(msg);
    } catch (_) {
      throw PaymentException('Connexion impossible pour le moment. Vérifiez votre réseau.');
    }
  }

  static Future<PaymentStart> start({required String offer, required int months, required String phone, String promo = ''}) async {
    final d = await _call({'action': 'payer', 'offre': offer, 'mois': months, 'telephone': phone, if (promo.isNotEmpty) 'code_promo': promo});
    final id = d['paiement_id'];
    if (id is! String) throw PaymentException('Le paiement a échoué. Réessayez.');
    return PaymentStart(
      id: id,
      status: (d['statut'] as String?) ?? 'en_attente',
      amount: (d['montant'] as num?)?.round() ?? 0,
      ussd: d['ussd'] as String?,
      operator: d['operateur'] as String?,
    );
  }

  /// en_attente, reussi ou echoue (avec la raison donnée par l'opérateur, si connue).
  static Future<(String, String?)> check(String id) async {
    final d = await _call({'action': 'statut', 'paiement_id': id});
    return ((d['statut'] as String?) ?? 'en_attente', d['raison'] as String?);
  }
}
