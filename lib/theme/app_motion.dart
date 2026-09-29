import 'package:flutter/cupertino.dart';

/// Motion tokens: durations, curves and press physics.
class AppMotion {
  AppMotion._();

  /// Springy overshoot used for rings, bars and sheets.
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1);

  /// Softer spring for small decorative pieces.
  static const Curve springSoft = Cubic(0.32, 1.2, 0.36, 1);

  /// iOS-style standard easing.
  static const Curve standard = Cubic(0.32, 0.72, 0, 1);

  static const Curve exit = Cubic(0.4, 0, 1, 1);
  static const Curve enter = Cubic(0, 0, 0.2, 1);

  static const Duration instant = Duration(milliseconds: 120);
  static const Duration press = Duration(milliseconds: 150);
  static const Duration quick = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 380);
  static const Duration slow = Duration(milliseconds: 700);
  static const Duration ringFill = Duration(milliseconds: 900);
  static const Duration shimmer = Duration(milliseconds: 1400);
  static const Duration sheet = Duration(milliseconds: 460);
  static const Duration splash = Duration(milliseconds: 1100);

  /// Scale applied while an element is held down (CSS `active:scale-95`).
  static const double pressScale = 0.96;
  static const double pressScaleSmall = 0.94;
}
