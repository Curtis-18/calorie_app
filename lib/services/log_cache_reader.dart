import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_entry.dart';

/// Read-only access to the local food-log cache that the provider already
/// writes (`food_log_<yyyy-mm-dd>`). Used by the presentation layer to show a
/// logging streak and to let the user flip back through days that are cached
/// on the device. It never writes and never talks to the backend.
class LogCacheReader {
  LogCacheReader._();

  static const String _prefix = 'food_log_';

  static String keyFor(DateTime day) =>
      '$_prefix${day.toIso8601String().substring(0, 10)}';

  static DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Cached entries for [day], newest first. Never throws.
  static Future<List<FoodEntry>> entriesFor(DateTime day) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(keyFor(day)) ?? const <String>[];
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
      final prefs = await SharedPreferences.getInstance();
      final days = <DateTime>[];
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_prefix)) continue;
        final parsed = DateTime.tryParse(key.substring(_prefix.length));
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
      final prefs = await SharedPreferences.getInstance();
      bool hasEntries(DateTime day) =>
          (prefs.getStringList(keyFor(day)) ?? const <String>[]).isNotEmpty;

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
