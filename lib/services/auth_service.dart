import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleAuthService {
  static const _webClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
    _initialized = true;
  }

  static Future<void> signInWithGoogle() async {
    await ensureInitialized();

    final signIn = GoogleSignIn.instance;
    if (!signIn.supportsAuthenticate()) {
      throw Exception('Google sign-in not supported on this platform');
    }

    final googleUser = await signIn.authenticate();
    final idToken = googleUser.authentication.idToken;

    if (idToken == null) {
      throw Exception('Google sign-in did not return an ID token');
    }

    await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }
}