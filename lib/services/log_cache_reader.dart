import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_entry.dart';
import 'user_cache.dart';

/// Read-only access to the signed-in user's local food-log cache (written by
/// the food log provider under [UserCache.logKey]). Used by the presentation
/// layer to show a logging streak and to let the user flip back through days
/// that are cached on the device. It never writes and never talks to the
/// backend. Signed out, it reports nothing.
class LogCacheReader {
  LogCacheReader._();

  /// The signed-in user's prefs, after any one-time legacy migration, or
  /// null when nobody is signed in.
  static Future<(SharedPreferences, String)?> _scope() async {
    final userId = UserCache.currentUserId();
    if (userId == null) return null;
    await UserCache.migrateLegacy(userId);
    return (await SharedPreferences.getInstance(), userId);
  }

  static DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Cached entries for [day], newest first. Never throws.
  static Future<List<FoodEntry>> entriesFor(DateTime day) async {
    try {
      final scope = await _scope();
      if (scope == null) return const <FoodEntry>[];
      final (prefs, userId) = scope;
      final raw = prefs.getStringList(UserCache.logKey(userId, day)) ?? const <String>[];
      final entries = <FoodEntry>[];
      for (final item in raw) {
        try {
          entries.add(FoodEntry.fromJson(jsonDecode(item) as Map<String, dynamic>));
        } catch (_) {
          // Skip malformed cache rows.
        }
      }
      return entries;
    } catch (_) {
      return const <FoodEntry>[];
    }
  }

  /// Days with cached data, most recent first.
  static Future<List<DateTime>> cachedDays({int limit = 14}) async {
    try {
      final scope = await _scope();
      if (scope == null) return const <DateTime>[];
      final (prefs, userId) = scope;
      final prefix = UserCache.logPrefix(userId);
      final days = <DateTime>[];
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(prefix)) continue;
        final parsed = DateTime.tryParse(key.substring(prefix.length));
        if (parsed == null) continue;
        if ((prefs.getStringList(key) ?? const <String>[]).isEmpty) continue;
        days.add(_dayOnly(parsed));
      }
      days.sort((a, b) => b.compareTo(a));
      return days.take(limit).toList();
    } catch (_) {
      return const <DateTime>[];
    }
  }

  /// Consecutive days (ending today or yesterday) that have cached entries.
  static Future<int> currentStreak() async {
    try {
      final scope = await _scope();
      if (scope == null) return 0;
      final (prefs, userId) = scope;
      bool hasEntries(DateTime day) =>
          (prefs.getStringList(UserCache.logKey(userId, day)) ?? const <String>[]).isNotEmpty;

      final today = _dayOnly(DateTime.now());
      var cursor = hasEntries(today) ? today : today.subtract(const Duration(days: 1));
      if (!hasEntries(cursor)) return 0;

      var streak = 0;
      while (hasEntries(cursor) && streak < 400) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
      return streak;
    } catch (_) {
      return 0;
    }
  }
}
