import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sifa/services/analytics.dart';

void main() {
  final a = Analytics.instance;

  test('identifiant d\'appareil aléatoire, 24 caractères', () {
    final x = Analytics.newDeviceId();
    expect(x.length, 24);
    expect(Analytics.newDeviceId(), isNot(x));
  });

  test('envoi : lot JSON vers la table evenements, file vidée sur succès', () async {
    final seen = <http.Request>[];
    Analytics.client = MockClient((r) async {
      seen.add(r);
      return http.Response('', 201);
    });
    a.debugInit();
    a.track('analyse', {'ref': '1', 'maladie': 'coccidiosis'});
    await a.flush();
    expect(seen, isNotEmpty);
    expect(seen.first.url.path, '/rest/v1/evenements');
    final body = jsonDecode(seen.first.body) as List;
    expect(body.first['nom'], 'analyse');
    expect(body.first['appareil'], 'testdevice0001');
    expect(body.first['props']['maladie'], 'coccidiosis');
    expect(body.first.containsKey('user_id'), isFalse); // anonyme
    expect(a.pending, isEmpty);
  });

  test('hors connexion ou erreur serveur : les événements restent en attente', () async {
    Analytics.client = MockClient((r) async => http.Response('', 503));
    a.debugInit();
    a.track('ouverture');
    await a.flush();
    expect(a.pending.length, 1);
    Analytics.client = MockClient((r) async => throw http.ClientException('offline'));
    await a.flush();
    expect(a.pending.length, 1);
  });

  test('lot refusé (erreur 4xx) : abandonné pour ne pas bloquer la file', () async {
    Analytics.client = MockClient((r) async => http.Response('{}', 401));
    a.debugInit();
    a.track('ouverture');
    await a.flush();
    expect(a.pending, isEmpty);
  });

  test('mesure coupée : rien n\'est enregistré ni envoyé', () async {
    var calls = 0;
    Analytics.client = MockClient((r) async {
      calls++;
      return http.Response('', 201);
    });
    a.debugInit(enabled: false);
    a.track('ouverture');
    await a.flush();
    expect(a.pending, isEmpty);
    expect(calls, 0);
  });
}
