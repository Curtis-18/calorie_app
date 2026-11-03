import 'package:flutter/cupertino.dart';
import 'app_typography.dart';
import 'tracker_colors.dart';

/// Global Cupertino theme, for dark ("Obsidian") or light ("Paper") mode.
class AppTheme {
  AppTheme._();

  /// Kept for backwards compatibility with existing call sites.
  static const double radius = 28.0;

  /// The theme for whichever mode [TrackerColors] is currently in.
  static CupertinoThemeData get cupertino {
    return CupertinoThemeData(
      brightness: TrackerColors.brightness,
      primaryColor: TrackerColors.accentStart,
      primaryContrastingColor: TrackerColors.background,
      scaffoldBackgroundColor: TrackerColors.background,
      barBackgroundColor: TrackerColors.navFill,
      applyThemeToAll: true,
      textTheme: CupertinoTextThemeData(
        textStyle: AppType.body(),
        actionTextStyle: AppType.button(color: TrackerColors.accentStartText, size: 15),
        tabLabelTextStyle: AppType.tabLabel(),
        navTitleTextStyle: AppType.navTitle(),
        navLargeTitleTextStyle: AppType.navLargeTitle(),
        navActionTextStyle: AppType.button(color: TrackerColors.accentStartText, size: 15),
        pickerTextStyle: AppType.body(size: 21),
      ),
    );
  }

  /// Page background gradient wash.
  static LinearGradient get backdrop => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: TrackerColors.isDark
            ? const [Color(0xFF0B0C10), Color(0xFF0D0F14), Color(0xFF0B0C10)]
            : const [Color(0xFFF7F4F0), Color(0xFFFAF7F3), Color(0xFFF7F4F0)],
        stops: const [0.0, 0.55, 1.0],
      );
}
