import 'package:flutter/cupertino.dart';

/// Design tokens for the Obsidian / iOS visual language.
///
/// The palette is fixed-dark: every surface, border and text colour resolves
/// to a literal value so the UI never flips to a light or "dynamic" scheme.
class TrackerColors {
  TrackerColors._();

  // Base surfaces
  static const Color background = Color(0xFF0B0C10); // Deep Obsidian
  static const Color surface = Color(0xFF16181F); // Card
  static const Color surfaceElevated = Color(0xFF1C1E26); // Inputs, wells
  static const Color surfaceHigh = Color(0xFF252833); // Skeleton highlight

  // Hairlines
  static const Color border = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)
  static const Color borderStrong = Color(0x1FFFFFFF); // rgba(255, 255, 255, 0.12)
  static const Color divider = Color(0x14FFFFFF);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFF636366);

  // Calorie accent (Energizing Coral -> Amber)
  static const Color accentStart = Color(0xFFFF5E3A);
  static const Color accentEnd = Color(0xFFFF9500);
  static const Color primary = accentStart;
  static const Color secondary = accentEnd;
  static const Color accentGlow = Color(0x40FF5E3A); // rgba(255, 94, 58, 0.25)
  static const Color accentGlowSoft = Color(0x1FFFA060);
  static const Color accentWash = Color(0x1AFFFFFF);

  static const LinearGradient calorieGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentStart, accentEnd],
  );

  static const SweepGradient calorieSweep = SweepGradient(
    startAngle: -3 * 0.7853981634, // -135deg
    endAngle: 3 * 0.7853981634, // +135deg
    colors: [accentEnd, accentStart, accentStart, accentEnd],
    stops: [0.0, 0.28, 0.72, 1.0],
    tileMode: TileMode.clamp,
  );

  // Macro accents
  static const Color macroProtein = Color(0xFF30D158); // iOS Mint
  static const Color macroCarbs = Color(0xFFFFD60A); // Warm Gold
  static const Color macroFat = Color(0xFFBF5AF2); // Soft Violet
  static const Color macroCalories = accentStart;

  // Functional
  static const Color success = Color(0xFF30D158);
  static const Color warning = Color(0xFFFFD60A);
  static const Color error = Color(0xFFFF453A);

  // Frosted glass
  static const Color glassFill = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)
  static const Color glassFillStrong = Color(0x1FFFFFFF); // rgba(255, 255, 255, 0.12)
  static const Color glassTint = Color(0x0D0B0C10);
  static const Color navFill = Color(0xE00B0C10); // rgba(11, 12, 16, 0.88)
  static const Color sheetFill = Color(0xF00F1014);
  static const Color streakFill = Color(0x26FF9500); // Warm accent glass

  // Skeleton / shimmer
  static const Color shimmerBase = Color(0xFF1C1E26);
  static const Color shimmerHighlight = Color(0xFF252833);

  /// Alpha helper that keeps precision on 8-bit channels.
  static Color alpha(Color color, double opacity) =>
      color.withValues(alpha: opacity.clamp(0.0, 1.0));
}
