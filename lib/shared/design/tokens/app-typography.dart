import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app-colors.dart';

class AppTypography {
  static bool _isArabic(Locale? locale) => locale?.languageCode == 'ar';

  static TextStyle _display({
    required Color color,
    double fontSize = 30,
    double height = 1.08,
  }) {
    return GoogleFonts.changa(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color,
      height: height,
      letterSpacing: -0.3,
    );
  }

  static TextStyle _heading({
    required Color color,
    double fontSize = 18,
    double height = 1.2,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.changa(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle _body({
    required Color color,
    double fontSize = 14,
    double height = 1.5,
    FontWeight fontWeight = FontWeight.w400,
    double? letterSpacing,
  }) {
    return GoogleFonts.readexPro(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle _mono({
    required Color color,
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.5,
    double? letterSpacing,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Transitional static styles. New widgets should use Theme.of(context).
  static TextStyle get display =>
      _display(color: NashaatPalette.majlisNight.textPrimary);

  static TextStyle get title => _heading(
    color: NashaatPalette.majlisNight.textPrimary,
    fontSize: 24,
    height: 1.15,
  );

  static TextStyle get heading =>
      _heading(color: NashaatPalette.majlisNight.textPrimary);

  static TextStyle get body =>
      _body(color: NashaatPalette.majlisNight.textBody);

  static TextStyle get bodyMuted =>
      _body(color: NashaatPalette.majlisNight.textMuted);

  static TextStyle get label => _body(
    color: NashaatPalette.majlisNight.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static TextStyle get labelMuted =>
      _body(color: NashaatPalette.majlisNight.textMuted, fontSize: 12);

  static TextStyle get mono =>
      _mono(color: NashaatPalette.majlisNight.textPrimary);

  static TextStyle get monoStrong => _mono(
    color: NashaatPalette.majlisNight.textPrimary,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get sectionHeader => _mono(
    color: NashaatPalette.majlisNight.textMuted,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    height: 1.4,
  );

  static TextTheme get textTheme => getTextTheme();

  static TextTheme getTextTheme({
    Locale? locale,
    NashaatPalette palette = NashaatPalette.majlisNight,
  }) {
    final arabic = _isArabic(locale);
    final display = _display(
      color: palette.textPrimary,
      fontSize: arabic ? 27 : 30,
      height: arabic ? 1.35 : 1.08,
    );
    final title = _heading(
      color: palette.textPrimary,
      fontSize: arabic ? 22 : 24,
      height: arabic ? 1.4 : 1.15,
    );
    final heading = _heading(
      color: palette.textPrimary,
      height: arabic ? 1.4 : 1.2,
    );
    final body = _body(color: palette.textBody, height: arabic ? 1.75 : 1.5);
    final label = _body(
      color: palette.textPrimary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: arabic ? 1.6 : 1.4,
      letterSpacing: arabic ? null : 0.2,
    );

    return TextTheme(
      displayLarge: display.copyWith(fontSize: arabic ? 36 : 40),
      displayMedium: display,
      displaySmall: display.copyWith(fontSize: arabic ? 23 : 24),
      headlineLarge: title.copyWith(fontSize: arabic ? 24 : 26),
      headlineMedium: title,
      headlineSmall: title.copyWith(fontSize: arabic ? 19 : 20),
      titleLarge: heading.copyWith(fontSize: 20),
      titleMedium: heading,
      titleSmall: heading.copyWith(fontSize: 15),
      bodyLarge: body.copyWith(fontSize: 16),
      bodyMedium: body,
      bodySmall: body.copyWith(fontSize: 12),
      labelLarge: label.copyWith(fontSize: 14),
      labelMedium: label,
      labelSmall: label.copyWith(fontSize: 11),
    );
  }
}
