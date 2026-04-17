import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app-colors.dart';

class AppTypography {
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

  static TextTheme get textTheme => TextTheme(
        displayLarge: display.copyWith(fontSize: 40),
        displayMedium: display,
        displaySmall: display.copyWith(fontSize: 24),
        headlineLarge: title.copyWith(fontSize: 26),
        headlineMedium: title,
        headlineSmall: title.copyWith(fontSize: 18),
        titleLarge: heading.copyWith(fontSize: 20),
        titleMedium: heading,
        titleSmall: heading.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        bodyLarge: body.copyWith(fontSize: 16),
        bodyMedium: body,
        bodySmall: body.copyWith(fontSize: 12),
        labelLarge: label.copyWith(fontSize: 14),
        labelMedium: label,
        labelSmall: label.copyWith(fontSize: 11),
      );
}
