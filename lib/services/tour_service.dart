import 'package:shared_preferences/shared_preferences.dart';

/// Manages one-time seen-state flags for the in-app product tour.
///
/// Keys used by convention:
///   tour_seen_dashboard – dashboard spotlight tour ([dashboard])
class TourService {
  static const _prefix = 'tour_seen_';

  /// The first-run dashboard spotlight tour.
  static const dashboard = 'dashboard';

  /// Returns true if the feature identified by [key] has already been seen.
  static Future<bool> hasSeen(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$key') ?? false;
  }

  /// Marks the feature identified by [key] as seen.
  static Future<void> markSeen(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$key', true);
  }

  /// Resets the seen-state for [key] so the feature shows again.
  static Future<void> reset(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }
}
