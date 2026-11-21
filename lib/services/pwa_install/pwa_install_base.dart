/// How this browser can put NuStreak on the Home Screen.
enum InstallMode {
  /// Already installed, a phone build, or a browser with no way to do it:
  /// show nothing.
  none,

  /// Chrome, Edge and friends: the app can open the browser's own install
  /// dialog from a tap.
  prompt,

  /// iPhone and iPad: no install dialog exists; the person does it from the
  /// Share menu, so the app shows them how.
  ios,
}

/// The browser's install support, behind an interface so no screen needs to
/// know whether it is running in a browser. The real one lives in
/// `pwa_install_web.dart`; everywhere else [createPwaInstall] says "none".
abstract class PwaInstall {
  InstallMode get mode;

  /// Fires when [mode] may have changed (the browser decided the app is
  /// installable, or the person installed it).
  Stream<void> get changes;

  /// Opens the browser's install dialog. True if the person accepted. Must be
  /// called straight from a tap.
  Future<bool> prompt();
}
