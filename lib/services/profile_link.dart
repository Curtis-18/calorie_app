import 'package:flutter/foundation.dart';

/// Shareable profile links, the way people share a LinkedIn or Instagram
/// profile: `https://<app address>/u/<username>`. Opening one in the app asks
/// whether to add that person as a friend.
class ProfileLink {
  ProfileLink._();

  /// Where links point when the app isn't running in a browser (a phone
  /// build). In a browser the address it is running on is used, so links are
  /// always right whatever the domain.
  static const _defaultBase = String.fromEnvironment(
    'PROFILE_LINK_BASE',
    defaultValue: 'https://calorie-app-ug.vercel.app',
  );

  static String get base => kIsWeb ? Uri.base.origin : _defaultBase;

  /// The full link for [username].
  static String urlFor(String username, {String? base}) => '${base ?? ProfileLink.base}/u/$username';

  /// The link without `https://`, for showing on screen.
  static String display(String username, {String? base}) =>
      urlFor(username, base: base).replaceFirst(RegExp(r'^https?://'), '');

  static final _name = RegExp(r'^[A-Za-z][A-Za-z0-9_]{2,19}$');

  /// The username in a profile link, or null if [uri] isn't one.
  static String? usernameFrom(Uri uri) {
    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (parts.length != 2 || parts[0] != 'u') return null;
    final name = parts[1];
    return _name.hasMatch(name) ? name : null;
  }

  /// A link that was opened and hasn't been dealt with yet. It waits here
  /// through sign-in and onboarding until the main screen can show it.
  static final ValueNotifier<String?> pending = ValueNotifier(null);

  /// Remember [uri] if it is a profile link (called once at start-up).
  static void capture(Uri uri) {
    final name = usernameFrom(uri);
    if (name != null) pending.value = name;
  }

  static void clear() => pending.value = null;
}
