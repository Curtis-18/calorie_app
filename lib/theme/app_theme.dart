import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tracker_colors.dart';

class AppTheme {
  AppTheme._();

  static const double radius = 28.0;

  static ThemeData get dark {
    final base = GoogleFonts.nunitoSansTextTheme();
    final textTheme = base.copyWith(
      displayLarge: GoogleFonts.nunitoSans(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        color: TrackerColors.textPrimary,
        letterSpacing: -1,
      ),
      headlineLarge: GoogleFonts.nunitoSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: TrackerColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.nunitoSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: TrackerColors.textPrimary,
      ),
      titleMedium: GoogleFonts.nunitoSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: TrackerColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.nunitoSans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: TrackerColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.nunitoSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: TrackerColors.textSecondary,
      ),
      bodySmall: GoogleFonts.nunitoSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: TrackerColors.textSecondary,
      ),
      labelLarge: GoogleFonts.nunitoSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: TrackerColors.background,
      ),
      labelSmall: GoogleFonts.nunitoSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: TrackerColors.textSecondary,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: TrackerColors.background,
      colorScheme: const ColorScheme.dark(
        primary: TrackerColors.primary,
        secondary: TrackerColors.secondary,
        surface: TrackerColors.surface,
        error: TrackerColors.error,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: TrackerColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        iconTheme: const IconThemeData(color: TrackerColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: TrackerColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TrackerColors.primary,
          foregroundColor: TrackerColors.background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: TrackerColors.primary,
        foregroundColor: TrackerColors.background,
        elevation: 4,
        // no shape override here on purpose, forcing CircleBorder globally
        // was clipping the extended "SCAN MEAL" button's label. If a plain
        // circular FAB is needed somewhere else, set shape: CircleBorder()
        // on that specific FloatingActionButton, not here.
      ),
    );
  }
}