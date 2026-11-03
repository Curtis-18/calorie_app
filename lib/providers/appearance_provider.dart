import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/appearance.dart';

/// The light / dark / auto choice, remembered on this device.
class AppearanceNotifier extends StateNotifier<AppearanceMode> {
  AppearanceNotifier([super.initial = AppearanceMode.defaultMode]);

  static const prefsKey = 'appearance_mode';

  /// Read the saved choice. Called before the first frame, so the app opens
  /// in the right mode instead of flashing the wrong one.
  static Future<AppearanceMode> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppearanceMode.fromName(prefs.getString(prefsKey));
    } catch (_) {
      return AppearanceMode.defaultMode;
    }
  }

  Future<void> set(AppearanceMode mode) async {
    if (mode == state) return;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, mode.name);
    } catch (_) {
      // Storage unavailable: the choice still applies for this session.
    }
  }
}

final appearanceProvider = StateNotifierProvider<AppearanceNotifier, AppearanceMode>((ref) => AppearanceNotifier());
