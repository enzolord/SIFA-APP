import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

/// Connexion Supabase (Google). L'application reste utilisable hors connexion :
/// si Supabase n'est pas joignable ou pas initialisé, tout fonctionne en local.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final instance = AuthService._();

  bool _ready = false;
  bool get ready => _ready;

  SupabaseClient? get client => _ready ? Supabase.instance.client : null;
  User? get user => client?.auth.currentUser;
  bool get signedIn => user != null;
  String get email => user?.email ?? '';
  String get displayName {
    final m = user?.userMetadata;
    return (m?['full_name'] ?? m?['name'] ?? '') as String;
  }

  Future<void> init() async {
    try {
      await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseKey);
      _ready = true;
      Supabase.instance.client.auth.onAuthStateChange.listen((_) => notifyListeners());
      notifyListeners();
    } catch (e) {
      debugPrint('Supabase indisponible : $e');
    }
  }

  /// Renvoie null si la connexion a réussi, sinon un message d'erreur (en français,
  /// à passer par `tr()` à l'affichage). La chaîne vide signifie « annulé ».
  Future<String?> signInWithGoogle() async {
    final c = client;
    if (c == null) return 'Connexion impossible pour le moment. Vérifiez votre réseau.';
    if (AppConfig.googleWebClientId.isEmpty) {
      return "La connexion Google n'est pas encore configurée.";
    }
    try {
      final google = GoogleSignIn(serverClientId: AppConfig.googleWebClientId, scopes: const ['email']);
      final account = await google.signIn();
      if (account == null) return '';
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) return "Google n'a pas renvoyé de jeton de connexion.";
      await c.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: auth.accessToken,
      );
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Connexion Google : $e');
      return 'La connexion Google a échoué. Réessayez.';
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
      await client?.auth.signOut();
    } catch (e) {
      debugPrint('Déconnexion : $e');
    }
    notifyListeners();
  }
}
