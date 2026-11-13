import 'dart:typed_data';

import '../widgets/status_chip.dart';

enum Disease { healthy, coccidiosis, salmonella, newcastle }

/// Fiabilité affichée à l'éleveur. La photo seule ne donne jamais « forte ».
enum Reliability { high, medium, low }

class DiseaseInfo {
  const DiseaseInfo(this.name, this.shortName, this.status);

  /// Libellé de l'hypothèse (« Coccidiose probable »).
  final String name;

  /// Nom de la maladie seule (« Coccidiose »).
  final String shortName;
  final SifaStatus status;
}

const diseaseInfo = <Disease, DiseaseInfo>{
  Disease.healthy: DiseaseInfo('Fiente saine', 'Fiente saine', SifaStatus.ok),
  Disease.coccidiosis: DiseaseInfo('Coccidiose probable', 'Coccidiose', SifaStatus.danger),
  Disease.salmonella: DiseaseInfo('Salmonellose probable', 'Salmonellose', SifaStatus.danger),
  Disease.newcastle: DiseaseInfo('Maladie de Newcastle probable', 'Maladie de Newcastle', SifaStatus.danger),
};

class Diagnosis {
  Diagnosis({
    required this.disease,
    required this.confidence,
    required this.photo,
    DateTime? at,
    this.photoPath,
    this.photoProbs,
    Set<String>? signs,
    this.reliability = Reliability.medium,
  })  : at = at ?? DateTime.now(),
        signs = signs ?? const {};

  /// Hypothèse finale (photo + signes cochés).
  final Disease disease;
  final double confidence; // 0..1
  final Uint8List photo;
  final DateTime at;
  String? photoPath;

  /// Probabilités données par la photo seule, dans l'ordre de [Disease.values].
  /// Null pour les anciennes analyses enregistrées avant cette version.
  final List<double>? photoProbs;

  /// Identifiants des signes cochés par l'éleveur (voir services/triage.dart).
  final Set<String> signs;
  final Reliability reliability;

  DiseaseInfo get info => diseaseInfo[disease]!;

  Map<String, dynamic> toJson() => {
        'disease': disease.index,
        'confidence': confidence,
        'photoPath': photoPath,
        'at': at.toIso8601String(),
        if (photoProbs != null) 'probs': photoProbs,
        'signs': signs.toList(),
        'rel': reliability.index,
      };
}
