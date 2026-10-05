import 'package:flutter/material.dart';

import '../tokens/app-colors.dart';
import '../tokens/app-radii.dart';
import 'app-dashed-border.dart';

enum AppStatusTone { neutral, accent, reward, calm, locked, attention }

class AppStatusPill extends StatelessWidget {
  final String label;
  final AppStatusTone tone;
  final bool showDot;
  final bool? dashed;
  final IconData? icon;

  const AppStatusPill({
    super.key,
    required this.label,
    this.tone = AppStatusTone.neutral,
    this.showDot = false,
    this.dashed,
    this.icon,
  });

  Color _background(NashaatPalette palette) => switch (tone) {
    AppStatusTone.neutral => palette.raised,
    AppStatusTone.accent => palette.accent.withValues(alpha: 0.14),
    AppStatusTone.reward => palette.reward.withValues(alpha: 0.16),
    AppStatusTone.calm => palette.calm.withValues(alpha: 0.16),
    AppStatusTone.locked => palette.locked.withValues(alpha: 0.18),
    AppStatusTone.attention => palette.danger.withValues(alpha: 0.10),
  };

  Color _foreground(NashaatPalette palette) => switch (tone) {
    AppStatusTone.neutral => palette.textSecondary,
    AppStatusTone.accent => palette.accentText,
    AppStatusTone.reward => palette.rewardText,
    AppStatusTone.calm => palette.calmText,
    AppStatusTone.locked => palette.lockedText,
    AppStatusTone.attention => palette.dangerText,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final foreground = _foreground(palette);
    final isDashed = dashed ?? tone == AppStatusTone.attention;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _background(palette),
        border: isDashed || tone != AppStatusTone.neutral
            ? null
            : Border.all(color: palette.border),
        borderRadius: AppRadii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
          ],
          if (showDot) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
              child: const SizedBox(width: 6, height: 6),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (!isDashed) return content;
    return AppDashedBorder(
      radius: AppRadii.pill,
      color: foreground,
      child: content,
    );
  }
}
