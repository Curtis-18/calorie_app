import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which optional cards the Today screen shows. Chosen in Settings and
/// remembered on this device, like the appearance.
class DisplayPrefs {
  const DisplayPrefs({this.showMacros = true, this.showNutrients = true, this.launchToCamera = false});

  final bool showMacros;
  final bool showNutrients;

  /// Open the meal camera as soon as the app starts. Off by default: it asks
  /// for camera permission at first launch and only helps people who open the
  /// app to log (handover: PRODUCT ROADMAP P0.3, decision D1).
  final bool launchToCamera;

  DisplayPrefs copyWith({bool? showMacros, bool? showNutrients, bool? launchToCamera}) => DisplayPrefs(
        showMacros: showMacros ?? this.showMacros,
        showNutrients: showNutrients ?? this.showNutrients,
        launchToCamera: launchToCamera ?? this.launchToCamera,
      );
}

class DisplayPrefsNotifier extends StateNotifier<DisplayPrefs> {
  DisplayPrefsNotifier() : super(const DisplayPrefs()) {
    _load();
  }

  static const macrosKey = 'today_show_macros';
  static const nutrientsKey = 'today_show_nutrients';
  static const launchToCameraKey = 'launch_to_camera';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      state = DisplayPrefs(
        showMacros: prefs.getBool(macrosKey) ?? true,
        showNutrients: prefs.getBool(nutrientsKey) ?? true,
        launchToCamera: prefs.getBool(launchToCameraKey) ?? false,
      );
    } catch (_) {
      // Storage unavailable: everything stays visible.
    }
  }

  Future<void> setShowMacros(bool value) => _save(state.copyWith(showMacros: value), macrosKey, value);

  Future<void> setShowNutrients(bool value) => _save(state.copyWith(showNutrients: value), nutrientsKey, value);

  Future<void> setLaunchToCamera(bool value) => _save(state.copyWith(launchToCamera: value), launchToCameraKey, value);

  Future<void> _save(DisplayPrefs next, String key, bool value) async {
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {
      // The choice still applies for this session.
    }
  }
}

final displayPrefsProvider =
    StateNotifierProvider<DisplayPrefsNotifier, DisplayPrefs>((ref) => DisplayPrefsNotifier());
