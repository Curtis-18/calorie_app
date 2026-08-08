import 'package:flutter/material.dart';

class TrackerColors {
  TrackerColors._();

  // Primary Palette
  static const Color background = Color(0xFF0D1B1E); // Deep Midnight Emerald
  static const Color surface = Color(0xFF1A2E32);    // Lighter Emerald for cards
  static const Color primary = Color(0xFFA3E635);    // Electric Lime (Action color)
  static const Color secondary = Color(0xFF2DD4BF);  // Soft Teal (Balance color)
  
  // Neutral / Text
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color divider = Color(0xFF263D42);
  
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
