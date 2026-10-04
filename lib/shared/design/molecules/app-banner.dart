import 'package:flutter/material.dart';

import '../atoms/app-status-pill.dart';
import '../tokens/app-colors.dart';
import '../tokens/app-radii.dart';

class AppBanner extends StatelessWidget {
  final String message;
  final AppStatusTone tone;
  final IconData? icon;
  final Widget? action;

  const AppBanner({
    super.key,
    required this.message,
    this.tone = AppStatusTone.neutral,
    this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final color = switch (tone) {
      AppStatusTone.neutral => palette.textSecondary,
      AppStatusTone.accent => palette.accentText,
      AppStatusTone.reward => palette.rewardText,
      AppStatusTone.calm => palette.calmText,
      AppStatusTone.locked => palette.lockedText,
      AppStatusTone.attention => palette.dangerText,
    };
    final background = switch (tone) {
      AppStatusTone.neutral => palette.raised,
      AppStatusTone.accent => palette.accent.withValues(alpha: 0.12),
      AppStatusTone.reward => palette.reward.withValues(alpha: 0.14),
      AppStatusTone.calm => palette.calm.withValues(alpha: 0.14),
      AppStatusTone.locked => palette.locked.withValues(alpha: 0.16),
      AppStatusTone.attention => palette.danger.withValues(alpha: 0.10),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.control,
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: palette.textPrimary),
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}
