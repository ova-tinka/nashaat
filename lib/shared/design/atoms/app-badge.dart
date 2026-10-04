import 'package:flutter/material.dart';

import '../tokens/app-colors.dart';
import '../tokens/app-radii.dart';
import 'app-status-pill.dart';

class AppBadge extends StatelessWidget {
  final String label;
  final AppStatusTone tone;
  final Color? background;
  final Color? foreground;

  const AppBadge(
    this.label, {
    super.key,
    this.tone = AppStatusTone.neutral,
    this.background,
    this.foreground,
  });

  const AppBadge.acid(String label, {Key? key})
    : this(label, key: key, tone: AppStatusTone.accent);

  const AppBadge.signal(String label, {Key? key})
    : this(label, key: key, tone: AppStatusTone.reward);

  const AppBadge.error(String label, {Key? key})
    : this(label, key: key, tone: AppStatusTone.attention);

  const AppBadge.muted(String label, {Key? key})
    : this(label, key: key, tone: AppStatusTone.neutral);

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final toneForeground = _toneForeground(palette, tone);
    final toneBackground = _toneBackground(palette, tone);
    final textColor = foreground ?? toneForeground;
    final fillColor = background ?? toneBackground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: fillColor, borderRadius: AppRadii.sm),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

Color _toneBackground(NashaatPalette palette, AppStatusTone tone) =>
    switch (tone) {
      AppStatusTone.neutral => palette.raised,
      AppStatusTone.accent => palette.accent,
      AppStatusTone.reward => palette.reward,
      AppStatusTone.calm => palette.calm,
      AppStatusTone.locked => palette.locked,
      AppStatusTone.attention => palette.danger,
    };

Color _toneForeground(NashaatPalette palette, AppStatusTone tone) =>
    switch (tone) {
      AppStatusTone.neutral => palette.textPrimary,
      AppStatusTone.accent => palette.accentInk,
      AppStatusTone.reward => palette.rewardInk,
      AppStatusTone.calm => palette.calmInk,
      AppStatusTone.locked => Colors.white,
      AppStatusTone.attention => palette.dangerInk,
    };
