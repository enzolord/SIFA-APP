import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:android_id/android_id.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'analytics.dart';
import 'auth_service.dart';

/// Un message de la conversation (l'éleveur ou l'assistant).
class ChatTurn {
  const ChatTurn(this.fromUser, this.text);
  final bool fromUser;
  final String text;
}

/// Questions permises à l'éleveur, comptées par le serveur (elles survivent à une réinstallation).
class AssistantQuota {
  const AssistantQuota({required this.limit, required this.used, this.free = true});

  /// Nombre de questions autorisées (null = illimité).
  final int? limit;
  final int used;

  /// Vrai si le quota est celui, à vie, du compte sans formule.
  final bool free;

  int? get remaining => limit == null ? null : (limit! - used).clamp(0, limit!);
  bool get blocked => remaining == 0;

  static AssistantQuota? fromJson(Map<String, dynamic> j) {
    final l = j['limite'];
    final u = j['utilise'];
    if (l != null && l is! num) return null;
    return AssistantQuota(
      limit: (l as num?)?.toInt(),
      used: (u is num) ? u.toInt() : 0,
      free: j['gratuit'] != false,
    );
  }
}

/// Réponse de l'assistant et état du quota après cette question.
class AssistantAnswer {
  const AssistantAnswer(this.text, this.quota);
  final String text;
  final AssistantQuota? quota;
}

/// Erreur affichable à l'éleveur (texte en français, traduit à l'affichage).
class AssistantException implements Exception {
  const AssistantException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Le quota de questions est atteint : l'écran propose les formules.
class AssistantQuotaException extends AssistantException {
  const AssistantQuotaException(this.quota) : super('Vous avez posé toutes les questions de votre formule.');
  final AssistantQuota quota;
}

/// Conversation avec l'assistant SIFA (fonction Supabase `assistant-sifa`, qui interroge Gemini).
class VoiceAssistant {
  /// Remplaçable dans les tests.
  static http.Client client = http.Client();

  /// Nombre de messages envoyés au serveur (les plus récents).
  static const maxTurns = 10;

  static List<ChatTurn> trim(List<ChatTurn> all) {
    final t = all.length > maxTurns ? all.sublist(all.length - maxTurns) : List<ChatTurn>.of(all);
    return t;
  }

  static String body(List<ChatTurn> history, String lang, [String device = '']) => jsonEncode({
        'lang': lang == 'en' ? 'en' : 'fr',
        'appareil': device,
        'messages': [
          for (final m in trim(history)) {'role': m.fromUser ? 'user' : 'model', 'text': m.text},
        ],
      });

  /// Lit la réponse du serveur. Lève [AssistantQuotaException] si le quota est atteint,
  /// [AssistantException] si la réponse est vide ou invalide.
  static AssistantAnswer parse(int status, String raw) {
    Map<String, dynamic>? j;
    try {
      j = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}
    if (status == 402) {
      throw AssistantQuotaException(
          (j == null ? null : AssistantQuota.fromJson(j)) ?? const AssistantQuota(limit: 0, used: 0));
    }
    if (status == 429) {
      throw const AssistantException("L'assistant est très sollicité. Réessayez dans une minute.");
    }
    final r = j?['reponse'];
    if (status == 200 && r is String && r.trim().isNotEmpty) return AssistantAnswer(r.trim(), AssistantQuota.fromJson(j!));
    throw const AssistantException("L'assistant est indisponible pour le moment.");
  }

  static String? _device;

  /// Identifiant de l'appareil : il reste le même après une réinstallation (Android ID).
  /// Le serveur n'en garde qu'une empreinte.
  static Future<String> deviceId() async {
    if (_device != null) return _device!;
    String? id;
    try {
      id = await const AndroidId().getId();
    } catch (_) {}
    id = (id == null || id.length < 8) ? Analytics.instance.deviceId : id;
    return _device = id;
  }

  static Future<Map<String, String>> _headers() async {
    String? token;
    try {
      final a = AuthService.instance;
      if (a.signedIn) token = a.client?.auth.currentSession?.accessToken;
    } catch (_) {}
    return {
      'Content-Type': 'application/json',
      'apikey': AppConfig.supabaseKey,
      'Authorization': 'Bearer ${token ?? AppConfig.supabaseKey}',
    };
  }

  static Uri get _url => Uri.parse('${AppConfig.supabaseUrl}/functions/v1/assistant-sifa');

  static Future<AssistantAnswer> ask(List<ChatTurn> history, String lang) async {
    try {
      final r = await client
          .post(_url, headers: await _headers(), body: body(history, lang, await deviceId()))
          .timeout(const Duration(seconds: 20));
      return parse(r.statusCode, utf8.decode(r.bodyBytes));
    } on AssistantException {
      rethrow;
    } catch (e) {
      debugPrint('VoiceAssistant: $e');
      throw const AssistantException('Pas de connexion. Vérifiez votre réseau et réessayez.');
    }
  }

  /// Questions restantes (null si le serveur ne répond pas : on ne bloque alors personne).
  static Future<AssistantQuota?> status() async {
    try {
      final r = await client
          .post(_url, headers: await _headers(), body: jsonEncode({'action': 'statut', 'appareil': await deviceId()}))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      return AssistantQuota.fromJson(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('VoiceAssistant.status: $e');
      return null;
    }
  }

  /// Texte nettoyé avant lecture à voix haute : sans symboles de mise en forme ni emoji.
  static String speakable(String s) {
    var t = s.replaceAll(RegExp(r'[*_#`>~|]'), ' ');
    t = t.replaceAll(RegExp(r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true), '');
    t = t.replaceAll(RegExp(r'^\s*[-•]\s+', multiLine: true), '');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
