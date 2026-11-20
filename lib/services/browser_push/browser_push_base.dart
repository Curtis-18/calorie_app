/// What the browser lets us do about notifications. The real one runs only in
/// a web build; everywhere else [createBrowserPush] gives one that says it is
/// unsupported, so no screen needs to know which platform it is on.
abstract class BrowserPush {
  /// Whether this browser can show push notifications at all. False on a phone
  /// build, in browsers without the Push API, and on an iPhone until the app
  /// has been added to the Home Screen.
  bool get supported;

  /// On an iPhone or iPad, notifications only work once the site is added to
  /// the Home Screen and opened from there.
  bool get needsHomeScreenInstall;

  /// 'default' (not asked yet), 'granted' or 'denied'.
  String get permission;

  /// Ask for permission, then subscribe. Returns the subscription as JSON text,
  /// or null when the person said no. Must be called straight from a tap.
  Future<String?> subscribe(String publicKey);

  /// This browser's subscription as JSON text, if it has one.
  Future<String?> currentSubscription();

  /// Stop this browser being notified.
  Future<void> unsubscribe();
}
