import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/auth_gate.dart';
import 'app_dialog.dart';

/// Ask, then sign out and return to the sign-in screen. Log out used to be a
/// bare icon in the Today header, one accidental tap from being signed out.
///
/// Returns true when the person was signed out.
Future<bool> confirmAndLogOut(
  BuildContext context, {
  Future<void> Function()? signOut,
  WidgetBuilder? signedOutScreen,
}) async {
  final sure = await showAppDialog(
    context: context,
    title: 'Log out?',
    message: 'Your food log and streaks are saved to your account and will be here when you log back in.',
    confirmLabel: 'Log out',
    cancelLabel: 'Stay',
  );
  if (sure != true || !context.mounted) return false;

  final navigator = Navigator.of(context, rootNavigator: true);
  await (signOut ?? _signOut)();
  navigator.pushAndRemoveUntil(
    CupertinoPageRoute<void>(builder: signedOutScreen ?? (_) => const AuthGate()),
    (route) => false,
  );
  return true;
}

Future<void> _signOut() async {
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (_) {
    // Offline, or the session is already gone on the server: the default
    // sign-out throws and left the person signed in. Sign out on this
    // device regardless.
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
  }
}
