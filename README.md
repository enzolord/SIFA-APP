# SIFA

Application Android de détection de maladies avicoles à partir de photos de fientes (poulets de chair et poules pondeuses).

## Démarrer

```powershell
flutter create --platforms android --org com.invlab --project-name sifa .
flutter pub get
flutter run
```

La commande `flutter create .` ajoute seulement le dossier `android/` ; elle ne touche pas à `lib/`.

## Structure

- `lib/theme/` : jetons de la charte et thèmes clair/sombre
- `lib/widgets/` : logo, puce de statut, avertissement
- `lib/screens/` : 5 onglets (Accueil, Historique, Scanner, Conseils, Profil) et écran de résultat

Prochain sprint : caméra, modèle TFLite embarqué, stockage local, Supabase.

## État du Sprint 1 (en cours)

- Parcours de démarrage : connexion (démo), ferme, consentement
- Écran Conseils et remèdes depuis le résultat

- Prise de photo (appareil ou galerie) via `image_picker`
- `Classifier` : interface + `MockClassifier` (résultat factice, à remplacer par TFLite)
- Historique en mémoire ; résultat avec conseils et avertissement légal
- Ma ferme : bandes, saisie du jour (mortalité, aliment, eau, poids), stocks avec jours restants, finances (ventes, dépenses, marge), tâches
- Sauvegarde locale : `sifa.json` et photos dans les documents de l'app (`lib/services/persistence.dart`), rechargées au démarrage

## Mettre à jour le modèle d'analyse (sans réinstaller l'app)

1. Entraîner avec `tools/SIFA_entrainement_v2.ipynb` (Colab, GPU T4) → `sifa_fp16.tflite` + `labels.json`.
2. `python tools/publier_modele.py sifa_fp16.tflite labels.json 2` (version > précédente) → dossier `a_publier/`.
3. Supabase : exécuter `supabase/modeles_bucket.sql` (une fois), puis déposer `sifa_v2.tflite` et `manifest.json` dans le bucket `modeles`.
4. Les téléphones récupèrent le modèle au prochain lancement avec Internet ; vérification taille + SHA-256, retour au modèle livré en cas de problème.
