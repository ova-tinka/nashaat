import 'package:flutter/material.dart';

import '../../../app/app-router.dart';
import '../../../shared/design/molecules/app-card.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../model/achievement-progress-model.dart';
import '../view-model/achievements-view-model.dart';
import 'achievement-detail-screen.dart';

class AchievementsScreen extends StatelessWidget {
  final AchievementsViewModel viewModel;

  const AchievementsScreen({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading && viewModel.achievements.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator(color: AppColors.ink)),
      );
    }

    if (viewModel.error != null && viewModel.achievements.isEmpty) {
      return AppCard(
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(height: AppSpacing.sm),
            Text(
              viewModel.error!,
              style: AppTypography.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: viewModel.load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (viewModel.achievements.isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                size: 36,
                color: AppColors.inkMuted,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No active achievements yet.',
                style: AppTypography.bodyMuted,
              ),
            ],
          ),
        ),
      );
    }

    final unlockedCount = viewModel.achievements
        .where((item) => item.status == AchievementDisplayStatus.unlocked)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Achievement Collection', style: AppTypography.heading),
            Text(
              '$unlockedCount / ${viewModel.achievements.length} unlocked',
              style: AppTypography.mono,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            mainAxisExtent: 286,
          ),
          itemCount: viewModel.achievements.length,
          itemBuilder: (context, index) {
            final achievement = viewModel.achievements[index];
            return _AchievementCard(
              achievement: achievement,
              onTap: () => Navigator.of(
                context,
              ).pushNamed(AppRouter.achievementDetail, arguments: achievement),
            );
          },
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
    final definition = achievement.definition;
    final unlocked = achievement.status == AchievementDisplayStatus.unlocked;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: unlocked ? AppColors.acidMuted : AppColors.paper,
            border: Border.all(
              color: unlocked ? AppColors.ink : AppColors.paperBorder,
              width: unlocked ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    color: unlocked ? AppColors.acid : AppColors.paperAlt,
                    alignment: Alignment.center,
                    child: Icon(
                      achievementIcon(definition),
                      size: 22,
                      color: unlocked ? AppColors.ink : AppColors.inkMuted,
                    ),
                  ),
                  _StatusBadge(status: achievement.status),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                definition.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.heading.copyWith(fontSize: 15),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                definition.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMuted,
              ),
              const Spacer(),
              Text(achievement.rewardLabel, style: AppTypography.label),
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(
                value: definition.targetValue == 0
                    ? 0
                    : (achievement.progress / definition.targetValue).clamp(
                        0.0,
                        1.0,
                      ),
                minHeight: 6,
                color: AppColors.ink,
                backgroundColor: AppColors.paperBorder,
                borderRadius: BorderRadius.zero,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(achievement.progressLabel, style: AppTypography.monoStrong),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AchievementDisplayStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      AchievementDisplayStatus.locked => 'LOCKED',
      AchievementDisplayStatus.inProgress => 'IN PROGRESS',
      AchievementDisplayStatus.unlocked => 'UNLOCKED',
    };
    final background = switch (status) {
      AchievementDisplayStatus.locked => AppColors.paperAlt,
      AchievementDisplayStatus.inProgress => AppColors.signalMuted,
      AchievementDisplayStatus.unlocked => AppColors.acid,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      color: background,
      child: Text(
        label,
        style: AppTypography.sectionHeader.copyWith(
          fontSize: 8,
          color: AppColors.ink,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
