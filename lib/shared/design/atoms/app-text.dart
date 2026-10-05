import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../tokens/app-colors.dart';

enum _AppTextVariant {
  hero,
  display,
  title,
  heading,
  body,
  bodyMuted,
  label,
  mono,
  monoStrong,
  section,
}

class AppText extends StatelessWidget {
  final String text;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Color? color;
  final _AppTextVariant _variant;

  const AppText.display(
    this.text, {
    super.key,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  }) : _variant = _AppTextVariant.display;

  const AppText.hero(
    this.text, {
    super.key,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  }) : _variant = _AppTextVariant.hero;

  const AppText.title(
    this.text, {
    super.key,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  }) : _variant = _AppTextVariant.title;

  const AppText.heading(
    this.text, {
    super.key,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  }) : _variant = _AppTextVariant.heading;

  const AppText.body(
    this.text, {
    super.key,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  }) : _variant = _AppTextVariant.body;

  const AppText.bodyMuted(
    this.text, {
    super.key,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  }) : _variant = _AppTextVariant.bodyMuted;

  const AppText.label(
    this.text, {
    super.key,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  }) : _variant = _AppTextVariant.label;

  const AppText.mono(
    this.text, {
    super.key,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  }) : _variant = _AppTextVariant.mono;

  const AppText.monoStrong(
    this.text, {
    super.key,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  }) : _variant = _AppTextVariant.monoStrong;

  const AppText.section(
    this.text, {
    super.key,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  }) : _variant = _AppTextVariant.section;

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final textTheme = Theme.of(context).textTheme;
    final base = switch (_variant) {
      _AppTextVariant.hero => textTheme.displayLarge,
      _AppTextVariant.display => textTheme.displayMedium,
      _AppTextVariant.title => textTheme.headlineMedium,
      _AppTextVariant.heading => textTheme.titleMedium,
      _AppTextVariant.body => textTheme.bodyMedium,
      _AppTextVariant.bodyMuted => textTheme.bodyMedium?.copyWith(
        color: palette.textMuted,
      ),
      _AppTextVariant.label => textTheme.labelMedium,
      _AppTextVariant.mono => GoogleFonts.jetBrainsMono(
        color: palette.textPrimary,
        fontSize: 13,
        height: 1.5,
      ),
      _AppTextVariant.monoStrong => GoogleFonts.jetBrainsMono(
        color: palette.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
      _AppTextVariant.section => GoogleFonts.jetBrainsMono(
        color: palette.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
        height: 1.4,
      ),
    };

    return Text(
      text,
      style: (base ?? const TextStyle()).copyWith(color: color ?? base?.color),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

Widget appTextDisplay(
  String text, {
  TextAlign? align,
  Color? color,
  int? maxLines,
}) => AppText.display(text, textAlign: align, color: color, maxLines: maxLines);

Widget appTextTitle(
  String text, {
  TextAlign? align,
  Color? color,
  int? maxLines,
}) => AppText.title(text, textAlign: align, color: color, maxLines: maxLines);

Widget appTextHeading(
  String text, {
  TextAlign? align,
  Color? color,
  int? maxLines,
}) => AppText.heading(text, textAlign: align, color: color, maxLines: maxLines);

Widget appTextBody(
  String text, {
  TextAlign? align,
  Color? color,
  int? maxLines,
  TextOverflow? overflow,
}) => AppText.body(
  text,
  textAlign: align,
  color: color,
  maxLines: maxLines,
  overflow: overflow,
);

Widget appTextBodyMuted(String text, {TextAlign? align, int? maxLines}) =>
    AppText.bodyMuted(text, textAlign: align, maxLines: maxLines);

Widget appTextLabel(String text, {TextAlign? align, Color? color}) =>
    AppText.label(text, textAlign: align, color: color);

Widget appTextLabelMuted(String text, {TextAlign? align}) =>
    AppText.bodyMuted(text, textAlign: align);

Widget appTextMono(String text, {TextAlign? align, Color? color}) =>
    AppText.mono(text, textAlign: align, color: color);

Widget appTextMonoStrong(String text, {TextAlign? align, Color? color}) =>
    AppText.monoStrong(text, textAlign: align, color: color);

Widget appTextSection(String text) =>
    AppText.section(text, textAlign: TextAlign.start);
