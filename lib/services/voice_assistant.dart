import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// Un message de la conversation (l'éleveur ou l'assistant).
class ChatTurn {
  const ChatTurn(this.fromUser, this.text);
  final bool fromUser;
  final String text;
}

/// Erreur affichable à l'éleveur (texte en français, traduit à l'affichage).
class AssistantException implements Exception {
  const AssistantException(this.message);
  final String message;
  @override
  String toString() => message;
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

  static String body(List<ChatTurn> history, String lang) => jsonEncode({
        'lang': lang == 'en' ? 'en' : 'fr',
        'messages': [
          for (final m in trim(history)) {'role': m.fromUser ? 'user' : 'model', 'text': m.text},
        ],
      });

  /// Lit la réponse du serveur. Lève [AssistantException] si elle est vide ou invalide.
  static String parse(int status, String raw) {
    if (status == 429) {
      throw const AssistantException("L'assistant est très sollicité. Réessayez dans une minute.");
    }
    if (status != 200) throw const AssistantException("L'assistant est indisponible pour le moment.");
    try {
      final r = (jsonDecode(raw) as Map<String, dynamic>)['reponse'];
      if (r is String && r.trim().isNotEmpty) return r.trim();
    } catch (_) {}
    throw const AssistantException("L'assistant est indisponible pour le moment.");
  }

  static Future<String> ask(List<ChatTurn> history, String lang) async {
    try {
      final r = await client
          .post(
            Uri.parse('${AppConfig.supabaseUrl}/functions/v1/assistant-sifa'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': AppConfig.supabaseKey,
              'Authorization': 'Bearer ${AppConfig.supabaseKey}',
            },
            body: body(history, lang),
          )
          .timeout(const Duration(seconds: 20));
      return parse(r.statusCode, utf8.decode(r.bodyBytes));
    } on AssistantException {
      rethrow;
    } catch (e) {
      debugPrint('VoiceAssistant: $e');
      throw const AssistantException('Pas de connexion. Vérifiez votre réseau et réessayez.');
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
