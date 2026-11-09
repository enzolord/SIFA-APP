# SIFA App

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
- Ma ferme : bandes, saisie du jour (mortalité, aliment, eau, poids), stocks avec jours restants, finances (ventes, dépenses, marge), tâches — en mémoire pour l'instant
