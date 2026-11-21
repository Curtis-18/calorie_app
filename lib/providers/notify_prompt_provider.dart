import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the "Turn on notifications" card on Today has been put away. After
/// "Not now" it stays away for [quietDays], then asks once more; it never
/// reappears for someone who said yes or whose browser blocks notifications
/// (those are decided by the browser's own state, not here).
class NotifyPromptNotifier extends StateNotifier<bool> {
  NotifyPromptNotifier({DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(true) {
    _load();
  }

  static const dismissedKey = 'notify_card_dismissed_at';
  static const quietDays = 7;

  final DateTime Function() _now;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getInt(dismissedKey);
      final recent = at != null && _now().difference(DateTime.fromMillisecondsSinceEpoch(at)).inDays < quietDays;
      if (mounted) state = recent;
    } catch (_) {
      if (mounted) state = false; // storage unavailable: ask; closing it still works this session
    }
  }

  Future<void> dismiss() async {
    state = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(dismissedKey, _now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}

/// True while the card is put away (the initial answer, until storage is read,
/// so the card never flashes).
final notifyPromptHiddenProvider = StateNotifierProvider<NotifyPromptNotifier, bool>((ref) => NotifyPromptNotifier());
