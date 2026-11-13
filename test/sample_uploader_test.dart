import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sifa/models/diagnosis.dart';
import 'package:sifa/services/analytics.dart';
import 'package:sifa/services/sample_uploader.dart';

Diagnosis _diag({int bytes = 600}) => Diagnosis(
      disease: Disease.coccidiosis,
      confidence: 0.8123456,
      photo: Uint8List(bytes),
      at: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      signs: {'diarrhee'},
      reliability: Reliability.high,
    );

void main() {
  final u = SampleUploader.instance;

  setUp(() => Analytics.instance.debugInit());

  test('envoie la photo puis la fiche, sans nom ni compte', () async {
    final seen = <http.Request>[];
    SampleUploader.client = MockClient((r) async {
      seen.add(r);
      return http.Response('{}', 200);
    });
    final d = _diag();
    expect(await u.share(d), isTrue);
    expect(seen.length, 2);
    expect(seen[0].url.path, '/storage/v1/object/echantillons/testdevice0001/1700000000000.jpg');
    expect(seen[0].headers['Content-Type'], 'image/jpeg');
    expect(seen[1].url.path, '/rest/v1/echantillons');
    final row = jsonDecode(seen[1].body) as Map<String, dynamic>;
    expect(row['appareil'], 'testdevice0001');
    expect(row['ref'], '1700000000000');
    expect(row['maladie_app'], 'coccidiosis');
    expect(row['fiabilite'], 'high');
    expect(row['confiance'], 0.812);
    expect(row['signes'], ['diarrhee']);
    expect(row.containsKey('user_id'), isFalse);
    expect(u.wasShared(d), isTrue);
  });

  test('une photo déjà envoyée n\'est pas renvoyée', () async {
    var calls = 0;
    SampleUploader.client = MockClient((r) async {
      calls++;
      return http.Response('{}', 200);
    });
    final d = Diagnosis(disease: Disease.healthy, confidence: .9, photo: Uint8List(300), at: DateTime.fromMillisecondsSinceEpoch(1700000000500));
    expect(await u.share(d), isTrue);
    expect(await u.share(d), isTrue);
    expect(calls, 2); // un seul envoi : photo + fiche
  });

  test('échec réseau ou serveur : false, et la photo n\'est pas marquée envoyée', () async {
    SampleUploader.client = MockClient((r) async => http.Response('refus', 403));
    final d = Diagnosis(disease: Disease.salmonella, confidence: .7, photo: Uint8List(300), at: DateTime.fromMillisecondsSinceEpoch(1700000001000));
    expect(await u.share(d), isFalse);
    expect(u.wasShared(d), isFalse);
    SampleUploader.client = MockClient((r) async => throw http.ClientException('offline'));
    expect(await u.share(d), isFalse);
  });

  test('photo trop lourde (plus de 2 Mo) : ignorée sans appel réseau', () async {
    var calls = 0;
    SampleUploader.client = MockClient((r) async {
      calls++;
      return http.Response('{}', 200);
    });
    final d = Diagnosis(disease: Disease.newcastle, confidence: .7, photo: Uint8List(SampleUploader.maxBytes + 1), at: DateTime.fromMillisecondsSinceEpoch(1700000002000));
    expect(await u.share(d), isFalse);
    expect(calls, 0);
  });

  test('partage automatique désactivé par défaut : onAnalysis n\'envoie rien', () async {
    var calls = 0;
    SampleUploader.client = MockClient((r) async {
      calls++;
      return http.Response('{}', 200);
    });
    expect(u.auto, isFalse);
    u.onAnalysis(Diagnosis(disease: Disease.healthy, confidence: .9, photo: Uint8List(300), at: DateTime.fromMillisecondsSinceEpoch(1700000003000)));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(calls, 0);
  });
}
