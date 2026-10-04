import 'package:flutter/material.dart';

import '../tokens/app-colors.dart';
import '../tokens/app-radii.dart';
import 'app-dashed-border.dart';
import 'app-status-pill.dart';

class AppSelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppStatusTone tone;

  const AppSelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.tone = AppStatusTone.accent,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final foreground = selected
        ? _toneForeground(palette, tone)
        : palette.textSecondary;
    final background = selected
        ? _toneBackground(palette, tone)
        : Colors.transparent;
    final attention = tone == AppStatusTone.attention && selected;
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        border: attention ? null : Border.all(color: palette.border),
        borderRadius: AppRadii.pill,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: attention
            ? AppDashedBorder(
                radius: AppRadii.pill,
                color: palette.dangerText,
                child: content,
              )
            : content,
      ),
    );
  }
}

class AppDayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AppDayChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: selected ? palette.calm : palette.well,
            border: selected ? null : Border.all(color: palette.border),
            borderRadius: AppRadii.control,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: selected ? palette.calmInk : palette.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

Color _toneBackground(NashaatPalette palette, AppStatusTone tone) =>
    switch (tone) {
      AppStatusTone.neutral => palette.raised,
      AppStatusTone.accent => palette.accent.withValues(alpha: 0.14),
      AppStatusTone.reward => palette.reward.withValues(alpha: 0.16),
      AppStatusTone.calm => palette.calm.withValues(alpha: 0.16),
      AppStatusTone.locked => palette.locked.withValues(alpha: 0.18),
      AppStatusTone.attention => palette.danger.withValues(alpha: 0.10),
    };

Color _toneForeground(NashaatPalette palette, AppStatusTone tone) =>
    switch (tone) {
      AppStatusTone.neutral => palette.textPrimary,
      AppStatusTone.accent => palette.accentText,
      AppStatusTone.reward => palette.rewardText,
      AppStatusTone.calm => palette.calmText,
      AppStatusTone.locked => palette.lockedText,
      AppStatusTone.attention => palette.dangerText,
    };
