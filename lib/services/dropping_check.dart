import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

enum DroppingVerdict {
  /// Gemini confirme que la photo montre une fiente.
  dropping,

  /// Gemini voit autre chose (objet, écran, route...).
  notDropping,

  /// Pas de réponse : hors connexion, quota dépassé, fonction non déployée.
  /// L'analyse continue avec le modèle embarqué seul.
  unknown,
}

class DroppingCheckResult {
  const DroppingCheckResult(this.verdict, {this.seenFr = '', this.seenEn = ''});
  static const unknown = DroppingCheckResult(DroppingVerdict.unknown);

  final DroppingVerdict verdict;

  /// Ce que la photo montre selon Gemini (« un stylo »), quand ce n'est pas une fiente.
  final String seenFr;
  final String seenEn;
}

/// Contrôle en ligne : demande à Gemini, via la fonction Supabase `verifier-fiente`,
/// si la photo montre bien une fiente de poulet. Ne bloque jamais l'analyse :
/// sans réseau ou en cas d'erreur, le verdict est [DroppingVerdict.unknown].
class DroppingCheck {
  /// Certitude minimale pour refuser une photo sur l'avis de Gemini.
  static const minConfidence = 0.6;

  /// Remplaçable dans les tests.
  static http.Client client = http.Client();

  static Future<DroppingCheckResult> verify(Uint8List jpeg) async {
    if (!AppConfig.onlineCheck || jpeg.isEmpty) return DroppingCheckResult.unknown;
    try {
      final r = await client
          .post(
            Uri.parse('${AppConfig.supabaseUrl}/functions/v1/verifier-fiente'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': AppConfig.supabaseKey,
              'Authorization': 'Bearer ${AppConfig.supabaseKey}',
            },
            body: jsonEncode({'image': base64Encode(jpeg)}),
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return DroppingCheckResult.unknown;
      return parse(utf8.decode(r.bodyBytes));
    } catch (e) {
      debugPrint('DroppingCheck: $e');
      return DroppingCheckResult.unknown;
    }
  }

  @visibleForTesting
  static DroppingCheckResult parse(String body) {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      final isDropping = j['fiente'];
      final conf = (j['confiance'] as num?)?.toDouble() ?? 0;
      if (isDropping == true) return const DroppingCheckResult(DroppingVerdict.dropping);
      if (isDropping == false && conf >= minConfidence) {
        return DroppingCheckResult(
          DroppingVerdict.notDropping,
          seenFr: (j['objet_fr'] as String? ?? '').trim(),
          seenEn: (j['objet_en'] as String? ?? '').trim(),
        );
      }
    } catch (_) {/* réponse illisible : on ne bloque pas */}
    return DroppingCheckResult.unknown;
  }
}
