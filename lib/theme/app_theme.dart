import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tracker_colors.dart';

class AppTheme {
  AppTheme._();

  static const double radius = 28.0;

  static CupertinoThemeData get cupertino {
    final textStyle = GoogleFonts.nunitoSans(color: TrackerColors.textPrimary);
    return CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: TrackerColors.primary,
      scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
      barBackgroundColor: CupertinoColors.systemGroupedBackground,
      textTheme: CupertinoTextThemeData(
        textStyle: textStyle,
        navTitleTextStyle: textStyle.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
        navLargeTitleTextStyle: textStyle.copyWith(fontSize: 34, fontWeight: FontWeight.w700),
        actionTextStyle: textStyle.copyWith(color: TrackerColors.primary, fontWeight: FontWeight.w600),
      ),
    );
  }
}