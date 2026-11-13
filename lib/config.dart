/// Réglages publics de l'application (aucun secret ici).
/// La clé « publishable » de Supabase est faite pour être embarquée dans l'app :
/// la sécurité repose sur les règles RLS de la base, pas sur le secret de cette clé.
class AppConfig {
  static const supabaseUrl = 'https://qprgpmmvdjrmslfsraae.supabase.co';
  static const supabaseKey = 'sb_publishable_HfgFOYXWuyNAWrjDGWJjiA_7jSssFOK';

  /// ID client OAuth « Application Web » créé dans Google Cloud (n'est pas secret).
  /// À renseigner ici ou à la compilation : --dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '239039656040-onr85234fqh1a1v7qc69llfugemqdk3t.apps.googleusercontent.com',
  );

  /// Contrôle en ligne « est-ce bien une fiente ? » (Gemini via la fonction Supabase verifier-fiente).
  /// Sans réseau, l'application utilise seulement le modèle embarqué.
  static const onlineCheck = true;

  /// Version du modèle livré dans l'application (assets/model). Les modèles publiés ensuite
  /// dans Supabase (bucket « modeles ») portent un numéro plus grand et le remplacent.
  static const bundledModelVersion = 1;

  /// Fichier qui annonce le dernier modèle publié.
  static const modelManifestUrl = '$supabaseUrl/storage/v1/object/public/modeles/manifest.json';
  static const modelBaseUrl = '$supabaseUrl/storage/v1/object/public/modeles/';
}
