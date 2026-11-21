/// Where a long-press on the Home Screen icon can land (the manifest's
/// `shortcuts` open the app with `?shortcut=<name>`).
enum AppShortcut { log, bites, messages, insights }

/// The shortcut asked for in [uri], or null when there is none or it is not
/// one we know (an old or mistyped link just opens the app normally).
AppShortcut? shortcutFromUri(Uri uri) {
  final name = uri.queryParameters['shortcut'];
  if (name == null) return null;
  for (final shortcut in AppShortcut.values) {
    if (shortcut.name == name.toLowerCase()) return shortcut;
  }
  return null;
}
