import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether the user arrived through a password-reset link and must choose a
/// new password before anything else.
///
/// Supabase signs the user in when they open the emailed link and announces
/// it with [AuthChangeEvent.passwordRecovery]. Without this, [AuthGate] would
/// see a session and drop them straight into the app without ever asking for
/// a new password. [start] is called right after `Supabase.initialize`, and
/// the auth stream replays its latest event, so a link that was handled
/// during start-up is not missed.
class PasswordRecovery {
  PasswordRecovery._();

  static final ValueNotifier<bool> pending = ValueNotifier(false);
  static StreamSubscription<AuthState>? _sub;

  static void start(Stream<AuthState> authChanges) {
    _sub?.cancel();
    _sub = authChanges.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        pending.value = true;
      } else if (state.event == AuthChangeEvent.signedOut) {
        pending.value = false;
      }
    }, onError: (_) {});
  }

  /// The new password is saved, or the user backed out.
  static void clear() => pending.value = false;

  @visibleForTesting
  static void resetForTest() {
    _sub?.cancel();
    _sub = null;
    pending.value = false;
  }
}

/// Smallest password Supabase accepts by default. The server may be stricter;
/// its message is shown if so.
const minPasswordLength = 6;

String? validateEmail(String raw) {
  final email = raw.trim();
  if (email.isEmpty) return 'Enter the email you signed up with.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'That doesn\'t look like an email address.';
  }
  return null;
}

String? validateNewPassword(String password, String confirm) {
  if (password.length < minPasswordLength) {
    return 'Use at least $minPasswordLength characters.';
  }
  if (password != confirm) return 'The two passwords don\'t match.';
  return null;
}

/// Plain-language messages for the errors people actually hit.
String friendlyAuthError(Object error) {
  final text = error is AuthException ? '${error.message} ${error.code ?? ''}' : '$error';
  final lower = text.toLowerCase();
  if (lower.contains('rate limit') || lower.contains('over_email_send_rate_limit') || lower.contains('too many')) {
    return 'Too many tries. Wait a minute and try again.';
  }
  if (lower.contains('same_password') || lower.contains('different from the old')) {
    return 'Choose a password you haven\'t used before.';
  }
  if (lower.contains('weak_password') || lower.contains('at least')) {
    return error is AuthException ? error.message : 'That password is too weak.';
  }
  if (lower.contains('expired') || lower.contains('invalid') && lower.contains('token')) {
    return 'That link has expired. Ask for a new one.';
  }
  if (lower.contains('session') && lower.contains('missing')) {
    return 'That link has expired. Ask for a new one.';
  }
  if (error is AuthException) return error.message;
  return 'Something went wrong. Check your connection and try again.';
}

/// The two Supabase calls, injectable for tests.
class PasswordActions {
  PasswordActions({
    Future<void> Function(String email, String? redirectTo)? sendLink,
    Future<void> Function(String password)? setPassword,
  })  : sendLink = sendLink ?? _sendLink,
        setPassword = setPassword ?? _setPassword;

  final Future<void> Function(String email, String? redirectTo) sendLink;
  final Future<void> Function(String password) setPassword;

  static Future<void> _sendLink(String email, String? redirectTo) =>
      Supabase.instance.client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);

  static Future<void> _setPassword(String password) =>
      Supabase.instance.client.auth.updateUser(UserAttributes(password: password));

  /// Back to the site the user is on, so the link opens this app (web).
  /// On other platforms the project's Site URL is used until deep links exist.
  static String? get redirectTo => kIsWeb ? Uri.base.origin : null;
}
