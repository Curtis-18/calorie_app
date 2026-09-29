import 'package:flutter/cupertino.dart';
import 'app_typography.dart';
import 'tracker_colors.dart';

/// Global Cupertino theme for the dark "Obsidian" visual layer.
class AppTheme {
  AppTheme._();

  /// Kept for backwards compatibility with existing call sites.
  static const double radius = 28.0;

  static CupertinoThemeData get cupertino {
    return CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: TrackerColors.accentStart,
      primaryContrastingColor: TrackerColors.background,
      scaffoldBackgroundColor: TrackerColors.background,
      barBackgroundColor: TrackerColors.navFill,
      applyThemeToAll: true,
      textTheme: CupertinoTextThemeData(
        textStyle: AppType.body(),
        actionTextStyle: AppType.button(color: TrackerColors.accentStart, size: 15),
        tabLabelTextStyle: AppType.tabLabel(),
        navTitleTextStyle: AppType.navTitle(),
        navLargeTitleTextStyle: AppType.navLargeTitle(),
        navActionTextStyle: AppType.button(color: TrackerColors.accentStart, size: 15),
        pickerTextStyle: AppType.body(size: 21),
      ),
    );
  }

  /// Page background gradient wash used behind every screen.
  static const LinearGradient backdrop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B0C10), Color(0xFF0D0F14), Color(0xFF0B0C10)],
    stops: [0.0, 0.55, 1.0],
  );
}
