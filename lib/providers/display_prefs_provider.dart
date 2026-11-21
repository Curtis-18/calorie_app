import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which optional cards the Today screen shows. Chosen in Settings and
/// remembered on this device, like the appearance.
class DisplayPrefs {
  const DisplayPrefs({this.showMacros = true, this.showNutrients = true, this.launchToCamera = false, this.mealsOpen = true});

  final bool showMacros;
  final bool showNutrients;

  /// Open the meal camera as soon as the app starts. Off by default: it asks
  /// for camera permission at first launch and only helps people who open the
  /// app to log (handover: PRODUCT ROADMAP P0.3, decision D1).
  final bool launchToCamera;

  /// Whether "Today's meals" is unfolded. Folded, the day shows as one row of
  /// chips. Remembered on this device; open for someone new.
  final bool mealsOpen;

  DisplayPrefs copyWith({bool? showMacros, bool? showNutrients, bool? launchToCamera, bool? mealsOpen}) => DisplayPrefs(
        showMacros: showMacros ?? this.showMacros,
        showNutrients: showNutrients ?? this.showNutrients,
        launchToCamera: launchToCamera ?? this.launchToCamera,
        mealsOpen: mealsOpen ?? this.mealsOpen,
      );
}

class DisplayPrefsNotifier extends StateNotifier<DisplayPrefs> {
  DisplayPrefsNotifier() : super(const DisplayPrefs()) {
    _load();
  }

  static const macrosKey = 'today_show_macros';
  static const nutrientsKey = 'today_show_nutrients';
  static const launchToCameraKey = 'launch_to_camera';
  static const mealsOpenKey = 'today_meals_open';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      state = DisplayPrefs(
        showMacros: prefs.getBool(macrosKey) ?? true,
        showNutrients: prefs.getBool(nutrientsKey) ?? true,
        launchToCamera: prefs.getBool(launchToCameraKey) ?? false,
        mealsOpen: prefs.getBool(mealsOpenKey) ?? true,
      );
    } catch (_) {
      // Storage unavailable: everything stays visible.
    }
  }

  Future<void> setShowMacros(bool value) => _save(state.copyWith(showMacros: value), macrosKey, value);

  Future<void> setShowNutrients(bool value) => _save(state.copyWith(showNutrients: value), nutrientsKey, value);

  Future<void> setLaunchToCamera(bool value) => _save(state.copyWith(launchToCamera: value), launchToCameraKey, value);

  Future<void> setMealsOpen(bool value) => _save(state.copyWith(mealsOpen: value), mealsOpenKey, value);

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
