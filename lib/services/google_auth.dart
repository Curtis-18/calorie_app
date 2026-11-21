import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Where Google sends a native app back to after sign-in (a deep link the
/// phone routes to this app). It must also be listed under Redirect URLs in
/// Supabase (Authentication > URL Configuration).
const googleNativeRedirect = 'nustreak://login-callback';

/// Whether to offer "Continue with Google" on this platform.
///
/// On the web and on Android, yes. In an **iPhone app**, no: Apple's review
/// rule 4.8 asks for Sign in with Apple beside any other third-party sign-in,
/// and that needs the Apple developer account, so until it exists the button
/// stays off the iOS build (a person on iOS can still use the website, or an
/// email account). Remove the iOS case when Sign in with Apple is added.
bool googleSignInAvailable({bool? web, TargetPlatform? platform}) {
  if (web ?? kIsWeb) return true;
  return (platform ?? defaultTargetPlatform) == TargetPlatform.android;
}

/// The address Google should return to: the website itself on the web (the
/// same page, so the session is picked up on load), the deep link on a phone.
String googleRedirectUrl({required bool web, required String origin}) => web ? origin : googleNativeRedirect;

/// Starts Google sign-in through Supabase. On the web the browser leaves for
/// Google and comes back to the app with a session; on a phone the system
/// browser opens and returns by [googleNativeRedirect]. Either way the result
/// arrives through the auth stream, not through this call.
///
/// Throws [AuthException] when Supabase refuses (for instance the Google
/// provider is not switched on yet) and anything else for no connection.
Future<void> signInWithGoogle({SupabaseClient? client, bool? web, String? origin}) async {
  final isWeb = web ?? kIsWeb;
  final auth = (client ?? Supabase.instance.client).auth;
  await auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: googleRedirectUrl(web: isWeb, origin: origin ?? (isWeb ? Uri.base.origin : '')),
    // Always let the person pick the account, so a shared device doesn't
    // silently reuse the last one.
    queryParams: const {'prompt': 'select_account'},
    authScreenLaunchMode: isWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
  );
}
