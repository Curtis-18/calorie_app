import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:google_fonts/google_fonts.dart';
import 'tracker_colors.dart';

/// Typography scale for the app.
///
/// On Apple platforms we deliberately leave the font family unset so the
/// engine renders the real system face (SF Pro Display / SF Pro Text).
/// Everywhere else we fall back to Nunito Sans, the closest rounded open
/// counterpart, so the layout keeps its SF Pro Rounded character.
class AppType {
  AppType._();

  static bool get _isApple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static TextStyle _base({
    double size = 16,
    FontWeight weight = FontWeight.w500,
    double tracking = -0.2,
    double height = 1.25,
    Color color = TrackerColors.textPrimary,
  }) {
    final style = TextStyle(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: tracking,
      height: height,
      color: color,
    );
    if (_isApple) return style;
    return GoogleFonts.nunitoSans(
      textStyle: style,
    );
  }

  /// Huge metric numerals (calorie ring counter).
  static TextStyle display({double size = 56, Color color = TrackerColors.textPrimary}) =>
      _base(size: size, weight: FontWeight.w800, tracking: -2.0, height: 1.0, color: color);

  /// Large screen title.
  static TextStyle navTitle({double size = 17}) =>
      _base(size: size, weight: FontWeight.w700, tracking: -0.4, height: 1.2);

  static TextStyle navLargeTitle({double size = 34}) =>
      _base(size: size, weight: FontWeight.w800, tracking: -1.0, height: 1.1);

  static TextStyle title({Color color = TrackerColors.textPrimary}) =>
      _base(size: 20, weight: FontWeight.w700, tracking: -0.4, color: color);

  static TextStyle headline({Color color = TrackerColors.textPrimary}) =>
      _base(size: 16, weight: FontWeight.w700, tracking: -0.3, color: color);

  static TextStyle body({Color color = TrackerColors.textPrimary, double size = 15}) =>
      _base(size: size, weight: FontWeight.w500, tracking: -0.1, height: 1.4, color: color);

  static TextStyle callout({Color color = TrackerColors.textSecondary, double size = 13}) =>
      _base(size: size, weight: FontWeight.w500, tracking: -0.05, height: 1.35, color: color);

  static TextStyle caption({Color color = TrackerColors.textSecondary, double size = 12}) =>
      _base(size: size, weight: FontWeight.w600, tracking: 0, height: 1.25, color: color);

  /// All-caps section eyebrow.
  static TextStyle sectionLabel({Color color = TrackerColors.textSecondary}) => _base(
        size: 11,
        weight: FontWeight.w800,
        tracking: 1.6,
        height: 1.2,
        color: color,
      );

  static TextStyle button({Color color = TrackerColors.textPrimary, double size = 16}) =>
      _base(size: size, weight: FontWeight.w700, tracking: -0.2, color: color);

  static TextStyle tabLabel({Color color = TrackerColors.textSecondary}) =>
      _base(size: 10, weight: FontWeight.w700, tracking: 0.2, height: 1.1, color: color);
}
