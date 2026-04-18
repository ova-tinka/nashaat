import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app-colors.dart';

class AppTypography {
  static bool _isArabic(Locale? locale) => locale?.languageCode == 'ar';

  static TextStyle _bodyFont({
    required Locale? locale,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    required double height,
    double? letterSpacing,
  }) {
    final fn = _isArabic(locale) ? GoogleFonts.cairo : GoogleFonts.inter;
    return fn(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle get display => GoogleFonts.jetBrainsMono(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        height: 1.1,
        letterSpacing: -1,
      );

  static TextStyle get title => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        height: 1.2,
        letterSpacing: -0.5,
      );

  static TextStyle get heading => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        height: 1.3,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
        height: 1.5,
      );

  static TextStyle get bodyMuted => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.inkMuted,
        height: 1.5,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: 0.5,
        height: 1.4,
      );

  static TextStyle get labelMuted => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.inkMuted,
        height: 1.4,
      );

  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
        height: 1.5,
      );

  static TextStyle get monoStrong => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        height: 1.5,
      );

  static TextStyle get sectionHeader => GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.inkMuted,
        letterSpacing: 1.2,
        height: 1.4,
      );

  static TextTheme get textTheme => getTextTheme();

  static TextTheme getTextTheme({Locale? locale}) {
    final titleStyle = _isArabic(locale)
        ? GoogleFonts.cairo(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            height: 1.2,
          )
        : title;

    final headingStyle = _isArabic(locale)
        ? GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            height: 1.3,
          )
        : heading;

    final bodyStyle = _bodyFont(
      locale: locale,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.ink,
      height: 1.5,
    );

    final labelStyle = _bodyFont(
      locale: locale,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
      height: 1.4,
      letterSpacing: _isArabic(locale) ? null : 0.5,
    );

    return TextTheme(
      displayLarge: display.copyWith(fontSize: 40),
      displayMedium: display,
      displaySmall: display.copyWith(fontSize: 24),
      headlineLarge: titleStyle.copyWith(fontSize: 26),
      headlineMedium: titleStyle,
      headlineSmall: titleStyle.copyWith(fontSize: 18),
      titleLarge: headingStyle.copyWith(fontSize: 20),
      titleMedium: headingStyle,
      titleSmall:
          headingStyle.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: bodyStyle.copyWith(fontSize: 16),
      bodyMedium: bodyStyle,
      bodySmall: bodyStyle.copyWith(fontSize: 12),
      labelLarge: labelStyle.copyWith(fontSize: 14),
      labelMedium: labelStyle,
      labelSmall: labelStyle.copyWith(fontSize: 11),
    );
  }
}
