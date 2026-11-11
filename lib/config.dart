/// Réglages publics de l'application (aucun secret ici).
/// La clé « publishable » de Supabase est faite pour être embarquée dans l'app :
/// la sécurité repose sur les règles RLS de la base, pas sur le secret de cette clé.
class AppConfig {
  static const supabaseUrl = 'https://qprgpmmvdjrmslfsraae.supabase.co';
  static const supabaseKey = 'sb_publishable_HfgFOYXWuyNAWrjDGWJjiA_7jSssFOK';

  /// ID client OAuth « Application Web » créé dans Google Cloud (n'est pas secret).
  /// À renseigner ici ou à la compilation : --dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');
}
