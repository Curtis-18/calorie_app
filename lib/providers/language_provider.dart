import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_language.dart';

/// The language chosen in Settings, or null to follow the device. Remembered
/// on this device, like the appearance.
class LanguageNotifier extends StateNotifier<String?> {
  LanguageNotifier([super.initial]);

  static const prefsKey = 'app_language';

  /// Read the saved choice before the first frame so the app opens in the right language.
  static Future<String?> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(prefsKey);
      return isSupportedLanguage(saved) ? saved : null;
    } catch (_) {
      return null;
    }
  }

  /// [code] null = follow the device.
  Future<void> set(String? code) async {
    final next = isSupportedLanguage(code) ? code : null;
    if (next == state) return;
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (next == null) {
        await prefs.remove(prefsKey);
      } else {
        await prefs.setString(prefsKey, next);
      }
    } catch (_) {
      // Storage unavailable: the choice still applies for this session.
    }
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, String?>((ref) => LanguageNotifier());

/// The language actually on screen: the choice, else the device's, else English.
/// Follows the device live while the choice is "automatic".
final activeLanguageProvider = Provider<String>((ref) {
  final saved = ref.watch(languageProvider);
  return resolveLanguage(saved: saved, deviceLocales: WidgetsBinding.instance.platformDispatcher.locales);
});
