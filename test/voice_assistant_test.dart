import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sifa/services/voice_assistant.dart';

void main() {
  test('le corps envoyé garde les 10 derniers messages et la langue', () {
    final h = [for (var i = 0; i < 14; i++) ChatTurn(i.isEven, 'm$i')];
    final b = jsonDecode(VoiceAssistant.body(h, 'en')) as Map<String, dynamic>;
    final msgs = b['messages'] as List;
    expect(b['lang'], 'en');
    expect(msgs.length, 10);
    expect((msgs.first as Map)['text'], 'm4');
    expect((msgs.first as Map)['role'], 'user');
    expect((msgs.last as Map)['role'], 'model');
  });

  test('langue inconnue : français', () {
    expect(jsonDecode(VoiceAssistant.body([const ChatTurn(true, 'a')], 'xx'))['lang'], 'fr');
  });

  test('lecture de la réponse et des erreurs', () {
    final a = VoiceAssistant.parse(200, '{"reponse":" Bonjour ","limite":10,"utilise":3,"gratuit":true}');
    expect(a.text, 'Bonjour');
    expect(a.quota!.remaining, 7);
    expect(a.quota!.free, isTrue);
    expect(VoiceAssistant.parse(200, '{"reponse":"x","limite":null,"utilise":50,"gratuit":false}').quota!.remaining, isNull);
    expect(() => VoiceAssistant.parse(200, '{"reponse":""}'), throwsA(isA<AssistantException>()));
    expect(() => VoiceAssistant.parse(200, 'pas du json'), throwsA(isA<AssistantException>()));
    expect(() => VoiceAssistant.parse(429, ''), throwsA(isA<AssistantException>()));
    expect(
        () => VoiceAssistant.parse(402, '{"erreur":"quota","limite":30,"utilise":30,"gratuit":false}'),
        throwsA(isA<AssistantQuotaException>().having((e) => e.quota.blocked, 'bloqué', true).having((e) => e.quota.free, 'gratuit', false)));
    expect(() => VoiceAssistant.parse(502, ''), throwsA(isA<AssistantException>()));
  });

  test('ask : succès, puis hors connexion', () async {
    VoiceAssistant.client = MockClient((r) async {
      expect(r.url.path, '/functions/v1/assistant-sifa');
      return http.Response.bytes(utf8.encode('{"reponse":"Isolez les poulets malades."}'), 200);
    });
    expect((await VoiceAssistant.ask([const ChatTurn(true, 'Mes poulets toussent')], 'fr')).text, 'Isolez les poulets malades.');
    VoiceAssistant.client = MockClient((r) async => throw http.ClientException('offline'));
    await expectLater(VoiceAssistant.ask([const ChatTurn(true, 'x')], 'fr'), throwsA(isA<AssistantException>()));
  });

  test('statut : questions restantes, ou null si le serveur ne répond pas', () async {
    VoiceAssistant.client = MockClient((r) async {
      expect(jsonDecode(r.body)['action'], 'statut');
      return http.Response('{"limite":10,"utilise":4,"restant":6,"gratuit":true,"offre":null}', 200);
    });
    final q = await VoiceAssistant.status();
    expect(q!.remaining, 6);
    expect(q.blocked, isFalse);
    VoiceAssistant.client = MockClient((r) async => http.Response('', 502));
    expect(await VoiceAssistant.status(), isNull);
  });

  test('quota atteint = bloqué', () {
    expect(const AssistantQuota(limit: 10, used: 10).blocked, isTrue);
    expect(const AssistantQuota(limit: null, used: 999).blocked, isFalse);
    expect(const AssistantQuota(limit: 5, used: 9).remaining, 0);
  });

  test('speakable retire la mise en forme', () {
    expect(VoiceAssistant.speakable('**Isolez** les poulets 🐔 malades.\n- Appelez le vétérinaire'),
        'Isolez les poulets malades. Appelez le vétérinaire');
  });
}
