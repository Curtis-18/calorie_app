import 'package:flutter/cupertino.dart';
import 'tracker_colors.dart';

/// Corner radius, spacing and decoration tokens.
class AppRadii {
  AppRadii._();

  /// Main containers / cards.
  static const double container = 28;
  /// Buttons, text fields, sheets (top corners).
  static const double button = 16;
  /// Chips, thumbnails, small wells.
  static const double small = 12;
  /// Compact tiles.
  static const double tiny = 10;
  /// Fully rounded.
  static const double pill = 999;

  static BorderRadius get containerAll => BorderRadius.circular(container);
  static BorderRadius get buttonAll => BorderRadius.circular(button);
  static BorderRadius get smallAll => BorderRadius.circular(small);

  static BorderRadius get sheetTop =>
      const BorderRadius.vertical(top: Radius.circular(container));
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  /// Horizontal page gutter.
  static const double gutter = 24;
  /// Room for the floating tab bar + FAB stack.
  static const double tabBarClearance = 118;
}

class AppDecor {
  AppDecor._();

  static const double blur = 20;

  /// Standard card: #16181F surface with a 1px rgba(255,255,255,0.08) border.
  static BoxDecoration card({
    Color? color,
    Gradient? gradient,
    BorderRadius? borderRadius,
    Border? border,
    List<BoxShadow>? shadow,
  }) =>
      BoxDecoration(
        color: color ?? (gradient == null ? TrackerColors.surface : null),
        gradient: gradient,
        borderRadius: borderRadius ?? AppRadii.containerAll,
        border: border ?? Border.all(color: TrackerColors.border, width: 1),
        boxShadow: shadow,
      );

  /// Frosted glass fill used on headers, sheets, tab bar and floating chips.
  static BoxDecoration glass({
    double opacity = 0.08,
    BorderRadius? borderRadius,
    Border? border,
    Color? tint,
    bool blurSurface = true,
  }) =>
      BoxDecoration(
        color: tint == null
            ? TrackerColors.alpha(TrackerColors.textPrimary, opacity)
            : TrackerColors.alpha(tint, opacity),
        borderRadius: borderRadius ?? AppRadii.containerAll,
        border: border ?? Border.all(color: TrackerColors.border, width: 1),
      );

  /// Soft tinted well (input fields, progress tracks).
  static BoxDecoration well({BorderRadius? borderRadius, Color? color}) => BoxDecoration(
        color: color ?? TrackerColors.surfaceElevated,
        borderRadius: borderRadius ?? AppRadii.buttonAll,
        border: Border.all(color: TrackerColors.border, width: 1),
      );

  /// Outer glow, e.g. `0 0 20px rgba(255, 94, 58, 0.25)`.
  static List<BoxShadow> glow(Color color, {double blur = 20, double opacity = 0.25, double spread = 0}) => [
        BoxShadow(
          color: TrackerColors.alpha(color, opacity),
          blurRadius: blur,
          spreadRadius: spread,
        ),
      ];

  /// Two-layer glow used behind the calorie ring and the FAB.
  static List<BoxShadow> layeredGlow(Color color, {double opacity = 0.25}) => [
        BoxShadow(color: TrackerColors.alpha(color, opacity), blurRadius: 20, spreadRadius: 0),
        BoxShadow(color: TrackerColors.alpha(color, opacity * 0.4), blurRadius: 44, spreadRadius: 4),
      ];

  static const Border hairlineTop = Border(top: BorderSide(color: TrackerColors.border, width: 1));
  static const Border none = Border();
}
