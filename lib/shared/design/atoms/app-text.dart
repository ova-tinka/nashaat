import 'package:flutter/material.dart';
import '../tokens/app-typography.dart';
import '../tokens/app-colors.dart';

class AppText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Color? color;

  const AppText.display(this.text, {super.key, this.textAlign, this.maxLines, this.overflow, this.color})
      : style = const _Stub();
  const AppText.title(this.text, {super.key, this.textAlign, this.maxLines, this.overflow, this.color})
      : style = const _Stub();
  const AppText.heading(this.text, {super.key, this.textAlign, this.maxLines, this.overflow, this.color})
      : style = const _Stub();
  const AppText.body(this.text, {super.key, this.textAlign, this.maxLines, this.overflow, this.color})
      : style = const _Stub();
  const AppText.bodyMuted(this.text, {super.key, this.textAlign, this.maxLines, this.overflow, this.color})
      : style = const _Stub();
  const AppText.label(this.text, {super.key, this.textAlign, this.maxLines, this.overflow, this.color})
      : style = const _Stub();
  const AppText.mono(this.text, {super.key, this.textAlign, this.maxLines, this.overflow, this.color})
      : style = const _Stub();
  const AppText.monoStrong(this.text, {super.key, this.textAlign, this.maxLines, this.overflow, this.color})
      : style = const _Stub();
  const AppText.section(this.text, {super.key, this.textAlign, this.maxLines, this.overflow, this.color})
      : style = const _Stub();

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

// Proper implementation using factory helpers:

class _AppTextImpl extends StatelessWidget {
  final String text;
  final TextStyle base;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Color? color;

  const _AppTextImpl({
    required this.text,
    required this.base,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = color != null ? base.copyWith(color: color) : base;
    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

// Functional helpers — use these in the app:
Widget appTextDisplay(String t, {TextAlign? align, Color? color, int? maxLines}) =>
    _AppTextImpl(text: t, base: AppTypography.display, textAlign: align, color: color, maxLines: maxLines);

Widget appTextTitle(String t, {TextAlign? align, Color? color, int? maxLines}) =>
    _AppTextImpl(text: t, base: AppTypography.title, textAlign: align, color: color, maxLines: maxLines);

Widget appTextHeading(String t, {TextAlign? align, Color? color, int? maxLines}) =>
    _AppTextImpl(text: t, base: AppTypography.heading, textAlign: align, color: color, maxLines: maxLines);

Widget appTextBody(String t, {TextAlign? align, Color? color, int? maxLines, TextOverflow? overflow}) =>
    _AppTextImpl(text: t, base: AppTypography.body, textAlign: align, color: color, maxLines: maxLines, overflow: overflow);

Widget appTextBodyMuted(String t, {TextAlign? align, int? maxLines}) =>
    _AppTextImpl(text: t, base: AppTypography.bodyMuted, textAlign: align, maxLines: maxLines);

Widget appTextLabel(String t, {TextAlign? align, Color? color}) =>
    _AppTextImpl(text: t, base: AppTypography.label, textAlign: align, color: color);

Widget appTextLabelMuted(String t, {TextAlign? align}) =>
    _AppTextImpl(text: t, base: AppTypography.labelMuted, textAlign: align);

Widget appTextMono(String t, {TextAlign? align, Color? color}) =>
    _AppTextImpl(text: t, base: AppTypography.mono, textAlign: align, color: color);

Widget appTextMonoStrong(String t, {TextAlign? align, Color? color}) =>
    _AppTextImpl(text: t, base: AppTypography.monoStrong, textAlign: align, color: color);

Widget appTextSection(String t) =>
    _AppTextImpl(text: t.toUpperCase(), base: AppTypography.sectionHeader);

// Ignore the stub; it's just there so the named constructors compile.
class _Stub extends TextStyle {
  const _Stub() : super(fontSize: 0, color: AppColors.ink);
}
