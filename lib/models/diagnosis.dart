import 'dart:typed_data';

import '../widgets/status_chip.dart';

enum Disease { healthy, coccidiosis, salmonella, newcastle }

class DiseaseInfo {
  const DiseaseInfo(this.name, this.status, this.advice);
  final String name;
  final SifaStatus status;
  final List<String> advice;
}

const diseaseInfo = <Disease, DiseaseInfo>{
  Disease.healthy: DiseaseInfo('Fiente saine', SifaStatus.ok, [
    'Continuez la surveillance habituelle.',
    "Vérifiez l'eau et l'aliment chaque jour.",
  ]),
  Disease.coccidiosis: DiseaseInfo('Coccidiose probable', SifaStatus.danger, [
    'Isolez les sujets qui semblent atteints.',
    "Gardez la litière sèche et propre.",
    'Appelez votre vétérinaire : un traitement anticoccidien est nécessaire.',
  ]),
  Disease.salmonella: DiseaseInfo('Salmonellose probable', SifaStatus.danger, [
    'Isolez les sujets malades et lavez-vous les mains après chaque contact.',
    "Évitez de déplacer des animaux ou du matériel vers d'autres bâtiments.",
    'Appelez votre vétérinaire rapidement.',
  ]),
  Disease.newcastle: DiseaseInfo('Maladie de Newcastle probable', SifaStatus.danger, [
    'Isolez immédiatement la bande et limitez les visites.',
    'Appelez votre vétérinaire ou les services vétérinaires : maladie à déclarer.',
    'Ne vendez ni ne déplacez aucun oiseau.',
  ]),
};

class Diagnosis {
  Diagnosis({
    required this.disease,
    required this.confidence,
    required this.photo,
    DateTime? at,
    this.photoPath,
  }) : at = at ?? DateTime.now();

  final Disease disease;
  final double confidence; // 0..1
  final Uint8List photo;
  final DateTime at;
  String? photoPath;

  DiseaseInfo get info => diseaseInfo[disease]!;

  Map<String, dynamic> toJson() => {
        'disease': disease.index,
        'confidence': confidence,
        'photoPath': photoPath,
        'at': at.toIso8601String(),
      };
}
