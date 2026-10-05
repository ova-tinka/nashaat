import 'package:flutter/material.dart';

import '../../../app/app-router.dart';
import '../../../shared/design/atoms/app-status-pill.dart';
import '../../../shared/design/atoms/app-text.dart';
import '../../../shared/design/molecules/app-card.dart';
import '../../../shared/design/molecules/app-progress-bar.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-radii.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../model/achievement-progress-model.dart';
import '../view-model/achievements-view-model.dart';
import 'achievement-detail-screen.dart';

class AchievementsScreen extends StatelessWidget {
  final AchievementsViewModel viewModel;

  const AchievementsScreen({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;

    if (viewModel.isLoading && viewModel.achievements.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator(color: palette.accent)),
      );
    }

    if (viewModel.error != null && viewModel.achievements.isEmpty) {
      return AppCard.attention(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: palette.dangerText),
            const SizedBox(height: AppSpacing.sm),
            AppText.body(viewModel.error!, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: viewModel.load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (viewModel.achievements.isEmpty) {
      return AppCard.standard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              size: 36,
              color: palette.textMuted,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppText.bodyMuted('No active achievements yet.'),
          ],
        ),
      );
    }

    final unlockedCount = viewModel.achievements
        .where((item) => item.status == AchievementDisplayStatus.unlocked)
        .length;
    final progress = viewModel.achievements.isEmpty
        ? 0.0
        : unlockedCount / viewModel.achievements.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText.title('Achievement collection'),
            AppText.mono('$unlockedCount / ${viewModel.achievements.length}'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppProgressBar(value: progress, activeColor: palette.reward),
        const SizedBox(height: AppSpacing.xl),
        ...viewModel.achievements.map(
          (achievement) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _AchievementCard(
              achievement: achievement,
              onTap: () => Navigator.of(
                context,
              ).pushNamed(AppRouter.achievementDetail, arguments: achievement),
            ),
          ),
        ),
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final AchievementProgressModel achievement;
  final VoidCallback onTap;

  const _AchievementCard({required this.achievement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final definition = achievement.definition;
    final unlocked = achievement.status == AchievementDisplayStatus.unlocked;
    final progress = definition.targetValue == 0
        ? 0.0
        : (achievement.progress / definition.targetValue).clamp(0.0, 1.0);

    return AppCard.standard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: unlocked
          ? palette.card
          : palette.card.withValues(alpha: 0.82),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: unlocked
                  ? palette.reward.withValues(alpha: 0.18)
                  : palette.raised,
              borderRadius: AppRadii.card,
              border: Border.all(
                color: unlocked ? palette.reward : palette.border,
              ),
            ),
            child: Icon(
              achievementIcon(definition),
              color: unlocked ? palette.rewardText : palette.textMuted,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText.heading(
                        definition.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatusBadge(status: achievement.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                AppText.bodyMuted(
                  definition.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppProgressBar(
                        value: progress,
                        activeColor: unlocked ? palette.reward : palette.accent,
                        height: 6,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppText.mono(achievement.progressLabel),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AchievementDisplayStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      AchievementDisplayStatus.locked => ('Locked', AppStatusTone.locked),
      AchievementDisplayStatus.inProgress => (
        'In progress',
        AppStatusTone.calm,
      ),
      AchievementDisplayStatus.unlocked => ('Unlocked', AppStatusTone.reward),
    };
    return AppStatusPill(label: label, tone: tone);
  }
}
