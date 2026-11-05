import 'package:flutter/cupertino.dart';

/// Every colour that changes between dark and light mode.
///
/// The vivid brand accents (coral to amber) are the same in both modes and
/// live on [TrackerColors] as constants. What differs is everything around
/// them: surfaces, text, hairlines, glass, and the *ink* versions of the
/// accent and semantic colours, which are deepened in light mode so they stay
/// readable as text and icons on white.
class TrackerPalette {
  const TrackerPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceHigh,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accentStartText,
    required this.accentEndText,
    required this.accentGlow,
    required this.accentGlowSoft,
    required this.accentWash,
    required this.macroProtein,
    required this.macroCarbs,
    required this.macroFat,
    required this.success,
    required this.warning,
    required this.error,
    required this.freeze,
    required this.glassFill,
    required this.glassFillStrong,
    required this.glassTint,
    required this.navFill,
    required this.sheetFill,
    required this.streakFill,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.cardShadow,
  });

  final Brightness brightness;

  // Surfaces
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceHigh;

  // Hairlines
  final Color border;
  final Color borderStrong;
  final Color divider;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// The coral and amber accents as text and icon colours.
  final Color accentStartText;
  final Color accentEndText;
  final Color accentGlow;
  final Color accentGlowSoft;
  final Color accentWash;

  // Macros and status
  final Color macroProtein;
  final Color macroCarbs;
  final Color macroFat;
  final Color success;
  final Color warning;
  final Color error;
  final Color freeze;

  // Frosted glass
  final Color glassFill;
  final Color glassFillStrong;
  final Color glassTint;
  final Color navFill;
  final Color sheetFill;
  final Color streakFill;

  // Skeleton / shimmer
  final Color shimmerBase;
  final Color shimmerHighlight;

  /// Resting shadow under cards. Dark surfaces separate with a hairline and
  /// glow; on white, a soft shadow is what lifts a card off the page.
  final List<BoxShadow> cardShadow;

  bool get isDark => brightness == Brightness.dark;

  /// The original "Obsidian" look.
  static const dark = TrackerPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0B0C10), // Deep Obsidian
    surface: Color(0xFF16181F),
    surfaceElevated: Color(0xFF1C1E26),
    surfaceHigh: Color(0xFF252833),
    border: Color(0x14FFFFFF), // rgba(255, 255, 255, 0.08)
    borderStrong: Color(0x1FFFFFFF), // rgba(255, 255, 255, 0.12)
    divider: Color(0x14FFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8E8E93),
    textTertiary: Color(0xFF636366),
    accentStartText: TrackerColors.accentStart,
    accentEndText: TrackerColors.accentEnd,
    accentGlow: Color(0x407CF542),
    accentGlowSoft: Color(0x1F17D9C0),
    accentWash: Color(0x1AFFFFFF),
    macroProtein: Color(0xFF9B7BFF), // Electric Violet
    macroCarbs: Color(0xFFFFD60A), // Warm Gold
    macroFat: Color(0xFFFF5CAA), // Hot Pink
    success: Color(0xFF30D158),
    warning: Color(0xFFFFD60A),
    error: Color(0xFFFF453A),
    freeze: Color(0xFF64D2FF),
    glassFill: Color(0x14FFFFFF),
    glassFillStrong: Color(0x1FFFFFFF),
    glassTint: Color(0x0D0B0C10),
    navFill: Color(0xE00B0C10), // rgba(11, 12, 16, 0.88)
    sheetFill: Color(0xF00F1014),
    streakFill: Color(0x26FF9500),
    shimmerBase: Color(0xFF1C1E26),
    shimmerHighlight: Color(0xFF252833),
    cardShadow: [],
  );

  /// Warm paper and white cards. Text is a warm near-black so it sits with the
  /// coral accent instead of fighting it; every text colour clears WCAG AA on
  /// the surfaces it is used on (checked in `test/theme_mode_test.dart`).
  static const light = TrackerPalette(
    brightness: Brightness.light,
    background: Color(0xFFF4F7F5),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEDF1EF),
    surfaceHigh: Color(0xFFE0E7E4),
    border: Color(0x1A1F2937), // charcoal at 10%
    borderStrong: Color(0x291F2937), // 16%
    divider: Color(0x141F2937), // 8%
    textPrimary: Color(0xFF1F2937),
    textSecondary: Color(0xFF4B5563),
    textTertiary: Color(0xFF5B6675),
    accentStartText: Color(0xFF2B7A0B),
    accentEndText: Color(0xFF0A7468),
    accentGlow: Color(0x337CF542),
    accentGlowSoft: Color(0x1A17D9C0),
    accentWash: Color(0x0F1F2937),
    macroProtein: Color(0xFF6D3FE0),
    macroCarbs: Color(0xFF9A5F00),
    macroFat: Color(0xFFB81C6B),
    success: Color(0xFF126B31),
    warning: Color(0xFF9A5F00),
    error: Color(0xFFC62419),
    freeze: Color(0xFF0A6E9C),
    glassFill: Color(0xB3FFFFFF),
    glassFillStrong: Color(0xD9FFFFFF),
    glassTint: Color(0x0DFFFFFF),
    navFill: Color(0xEBFFFFFF), // rgba(255, 255, 255, 0.92)
    sheetFill: Color(0xF7F9FBFA),
    streakFill: Color(0x1FFF9500),
    shimmerBase: Color(0xFFE9EEEC),
    shimmerHighlight: Color(0xFFF6F9F8),
    cardShadow: [
      BoxShadow(color: Color(0x0D1F2937), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x141F2937), blurRadius: 20, spreadRadius: -2, offset: Offset(0, 4)),
    ],
  );
}

/// Design tokens for the Obsidian (dark) and Paper (light) visual languages.
///
/// The colour getters read the active [TrackerPalette], so a widget that calls
/// `TrackerColors.surface` gets whichever mode is on *when it builds*. Changing
/// the mode therefore needs a rebuild of the whole tree; see `ThemeHost`.
/// Because the values are no longer compile-time constants, they can't sit in a
/// `const` expression. The brand accents and gradients below still can.
class TrackerColors {
  TrackerColors._();

  static TrackerPalette _palette = TrackerPalette.dark;

  /// Bumped on every change, so custom painters (which read colours inside
  /// `paint`) can tell they need to repaint.
  static int _epoch = 0;

  static TrackerPalette get palette => _palette;
  static Brightness get brightness => _palette.brightness;
  static bool get isDark => _palette.isDark;
  static int get paletteEpoch => _epoch;

  /// Switch the app to [brightness]. Returns whether anything changed.
  static bool apply(Brightness brightness) {
    if (_palette.brightness == brightness) return false;
    _palette = brightness == Brightness.dark ? TrackerPalette.dark : TrackerPalette.light;
    _epoch++;
    return true;
  }

  // --- Brand accents: identical in both modes ------------------------------

  /// Energizing Coral and Amber. Use these for fills, gradients and glows.
  /// For coloured *text or icons*, use [accentStartText] / [accentEndText].
  static const Color accentStart = Color(0xFF7CF542);
  static const Color accentEnd = Color(0xFF17D9C0);
  static const Color primary = accentStart;
  static const Color secondary = accentEnd;

  /// Fire stays warm whatever the brand colour is: streak flames and embers.
  static const Color flameStart = Color(0xFFFF5E3A);
  static const Color flameEnd = Color(0xFFFF9500);

  /// What sits on top of an accent fill or gradient. Always white, whatever
  /// the mode, because the gradient is always vivid.
  static const Color onAccent = Color(0xFF062B1E);

  static const LinearGradient calorieGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentStart, accentEnd],
  );

  /// Seamless: the colours wrap round, so there is no hard edge anywhere.
  static const SweepGradient calorieSweep = SweepGradient(
    startAngle: 0,
    endAngle: 2 * 3.1415926536,
    colors: [accentStart, accentEnd, accentStart],
  );

  // --- Mode-dependent ------------------------------------------------------

  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get surfaceElevated => _palette.surfaceElevated;
  static Color get surfaceHigh => _palette.surfaceHigh;

  static Color get border => _palette.border;
  static Color get borderStrong => _palette.borderStrong;
  static Color get divider => _palette.divider;

  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.textSecondary;
  static Color get textTertiary => _palette.textTertiary;

  static Color get accentStartText => _palette.accentStartText;
  static Color get accentEndText => _palette.accentEndText;
  static Color get accentGlow => _palette.accentGlow;
  static Color get accentGlowSoft => _palette.accentGlowSoft;
  static Color get accentWash => _palette.accentWash;

  static Color get macroProtein => _palette.macroProtein;
  static Color get macroCarbs => _palette.macroCarbs;
  static Color get macroFat => _palette.macroFat;
  static Color get macroCalories => accentStart;

  static Color get success => _palette.success;
  static Color get warning => _palette.warning;
  static Color get error => _palette.error;
  static Color get freeze => _palette.freeze;

  static Color get glassFill => _palette.glassFill;
  static Color get glassFillStrong => _palette.glassFillStrong;
  static Color get glassTint => _palette.glassTint;
  static Color get navFill => _palette.navFill;
  static Color get sheetFill => _palette.sheetFill;
  static Color get streakFill => _palette.streakFill;

  static Color get shimmerBase => _palette.shimmerBase;
  static Color get shimmerHighlight => _palette.shimmerHighlight;

  static List<BoxShadow> get cardShadow => _palette.cardShadow;

  /// [c] as text or an icon: the brand accents swap to their deeper light-mode
  /// inks (lime on white is unreadable); any other colour is returned as is.
  static Color ink(Color c) {
    if (c == accentStart) return accentStartText;
    if (c == accentEnd) return accentEndText;
    return c;
  }

  /// Alpha helper that keeps precision on 8-bit channels.
  static Color alpha(Color color, double opacity) => color.withValues(alpha: opacity.clamp(0.0, 1.0));
}
