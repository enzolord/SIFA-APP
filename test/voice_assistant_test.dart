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
    expect(VoiceAssistant.parse(200, '{"reponse":" Bonjour "}'), 'Bonjour');
    expect(() => VoiceAssistant.parse(200, '{"reponse":""}'), throwsA(isA<AssistantException>()));
    expect(() => VoiceAssistant.parse(200, 'pas du json'), throwsA(isA<AssistantException>()));
    expect(() => VoiceAssistant.parse(429, ''), throwsA(isA<AssistantException>()));
    expect(() => VoiceAssistant.parse(502, ''), throwsA(isA<AssistantException>()));
  });

  test('ask : succès, puis hors connexion', () async {
    VoiceAssistant.client = MockClient((r) async {
      expect(r.url.path, '/functions/v1/assistant-sifa');
      return http.Response.bytes(utf8.encode('{"reponse":"Isolez les poulets malades."}'), 200);
    });
    expect(await VoiceAssistant.ask([const ChatTurn(true, 'Mes poulets toussent')], 'fr'), 'Isolez les poulets malades.');
    VoiceAssistant.client = MockClient((r) async => throw http.ClientException('offline'));
    await expectLater(VoiceAssistant.ask([const ChatTurn(true, 'x')], 'fr'), throwsA(isA<AssistantException>()));
  });

  test('speakable retire la mise en forme', () {
    expect(VoiceAssistant.speakable('**Isolez** les poulets 🐔 malades.\n- Appelez le vétérinaire'),
        'Isolez les poulets malades. Appelez le vétérinaire');
  });
}
