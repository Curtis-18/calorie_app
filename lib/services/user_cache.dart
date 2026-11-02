import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Device-cache keys, scoped to one signed-in user.
///
/// The cache used to be device-wide (`user_profile`, `food_log_<date>`), so
/// after user A signed out and user B signed in on the same phone or browser,
/// B was shown A's calorie targets, food history and streak. History and the
/// streak are read only from this cache, so every key now carries the user id.
class UserCache {
  UserCache._();

  /// Overridable in tests. Defaults to the Supabase session.
  static String? Function() currentUserId = _supabaseUserId;

  static String? _supabaseUserId() => Supabase.instance.client.auth.currentSession?.user.id;

  /// The signed-in user id over time: null on sign-out, the id otherwise.
  /// Consumers should ignore repeats (token refreshes re-emit the same id).
  static Stream<String?> userIdChanges() => Supabase.instance.client.auth.onAuthStateChange
      .map((auth) => auth.event == AuthChangeEvent.signedOut ? null : auth.session?.user.id);

  static String profileKey(String userId) => 'user_profile:$userId';

  static String logPrefix(String userId) => 'food_log:$userId:';

  static String logKey(String userId, DateTime day) =>
      '${logPrefix(userId)}${day.toIso8601String().substring(0, 10)}';

  /// The device-wide keys used before per-user scoping.
  static const legacyProfileKey = 'user_profile';
  static const legacyLogPrefix = 'food_log_';
  static const _migratedFlag = 'user_cache_migrated_v1';

  static Future<void>? _migration;

  /// One time per device: hand the pre-scoping cache to the first user who
  /// signs in after the update.
  ///
  /// On a device with one user (nearly all of them) that is the owner, so
  /// their history and streak carry over instead of disappearing. The old
  /// shared keys are then deleted, so the data can never reach a second user.
  static Future<void> migrateLegacy(String userId) =>
      _migration ??= _migrate(userId).whenComplete(() => _migration = null);

  static Future<void> _migrate(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedFlag) ?? false) return;

    final profile = prefs.getString(legacyProfileKey);
    if (profile != null) {
      if (!prefs.containsKey(profileKey(userId))) {
        await prefs.setString(profileKey(userId), profile);
      }
      await prefs.remove(legacyProfileKey);
    }

    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith(legacyLogPrefix)) continue;
      final day = DateTime.tryParse(key.substring(legacyLogPrefix.length));
      final entries = prefs.getStringList(key);
      if (day != null && entries != null) {
        final scoped = logKey(userId, day);
        if (!prefs.containsKey(scoped)) await prefs.setStringList(scoped, entries);
      }
      await prefs.remove(key);
    }

    await prefs.setBool(_migratedFlag, true);
  }

  /// Test hook: forget the in-flight migration between tests.
  static void resetForTest() => _migration = null;
}
