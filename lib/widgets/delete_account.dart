import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/auth_gate.dart';
import '../services/account_service.dart';
import 'app_dialog.dart';

/// Ask, then delete the signed-in person's account for good and return to the
/// sign-in screen. Nothing is deleted unless they confirm, and if the server
/// can't do it they are told and stay signed in with everything intact.
///
/// Returns true when the account was deleted.
Future<bool> confirmAndDeleteAccount(
  BuildContext context, {
  AccountService? service,
  Future<void> Function()? signOut,
  WidgetBuilder? signedOutScreen,
}) async {
  final sure = await showAppDialog(
    context: context,
    title: 'Delete your account?',
    message: 'This permanently deletes your profile, food log, weight history, friends, bites and streaks. '
        "It can't be undone.",
    confirmLabel: 'Delete',
    cancelLabel: 'Keep it',
    destructive: true,
  );
  if (sure != true || !context.mounted) return false;

  final navigator = Navigator.of(context, rootNavigator: true);
  showCupertinoDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0x99000000),
    builder: (_) => const AppLoadingDialog(label: 'Deleting your account…'),
  );

  try {
    await (service ?? AccountService()).deleteAccount();
  } on AccountException catch (e) {
    navigator.pop(); // the progress dialog
    if (context.mounted) {
      await showAppDialog(context: context, title: "Couldn't delete your account", message: e.message);
    }
    return false;
  }

  // The account no longer exists on the server, so only this device's
  // session needs clearing; a failure here must not undo the good news.
  try {
    await (signOut ?? _signOutLocally)();
  } catch (_) {}
  navigator.pushAndRemoveUntil(
    CupertinoPageRoute<void>(builder: signedOutScreen ?? (_) => const AuthGate()),
    (route) => false,
  );
  return true;
}

Future<void> _signOutLocally() => Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
