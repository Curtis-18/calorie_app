import 'package:flutter/cupertino.dart';

class TrackerColors {
  TrackerColors._();

  // Primary Palette
  static const Color background = CupertinoColors.systemGroupedBackground;
  static const Color surface = CupertinoColors.secondarySystemGroupedBackground;
  static const Color primary = CupertinoColors.activeBlue;
  static const Color secondary = CupertinoColors.activeGreen;
  
  // Neutral / Text
  static const Color textPrimary = CupertinoColors.label;
  static const Color textSecondary = CupertinoColors.secondaryLabel;
  static const Color divider = CupertinoColors.separator;
  
  // Functional Colors
  static const Color error = Color(0xFFFB7185);     // Soft Rose
  static const Color warning = Color(0xFFFBBF24);   // Amber
  static const Color success = Color(0xFF34D399);   // Mint
  
  // Macro Colors (Refined)
  static const Color macroCarbs = Color(0xFF38BDF8);   // Sky
  static const Color macroFat = Color(0xFFFACC15);     // Yellow
  static const Color macroProtein = Color(0xFFC084FC); // Lavender
  static const Color macroCalories = primary;
}
