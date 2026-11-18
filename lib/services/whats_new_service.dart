import 'package:shared_preferences/shared_preferences.dart';

import '../models/whats_new.dart';
import 'tour_service.dart';

/// Which "What's new" release each person has opened. On the device, per
/// person, so a shared phone shows it to each of them once.
class WhatsNewService {
  static String _key(String userId) => 'whats_new_seen:$userId';

  /// Whether there is a release this person hasn't opened. Someone brand new
  /// (still to see the first-run tutorial) has nothing "new": everything is
  /// new to them, so they are marked up to date instead.
  static Future<bool> hasUnread(String userId, {String latestId = ''}) async {
    final latest = latestId.isEmpty ? latestWhatsNew.id : latestId;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_key(userId)) == latest) return false;
    if (prefs.getString(_key(userId)) == null && !await TourService.hasSeen(TourService.dashboard)) {
      await prefs.setString(_key(userId), latest);
      return false;
    }
    return true;
  }

  static Future<void> markSeen(String userId, {String latestId = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), latestId.isEmpty ? latestWhatsNew.id : latestId);
  }
}
