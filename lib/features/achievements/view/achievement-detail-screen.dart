import 'package:flutter/material.dart';

import '../../../core/entities/achievement-entity.dart';
import '../../../core/entities/enums.dart';
import '../../../shared/design/atoms/app-divider.dart';
import '../../../shared/design/molecules/app-card.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../model/achievement-progress-model.dart';

class AchievementDetailScreen extends StatelessWidget {
  final AchievementProgressModel achievement;

  const AchievementDetailScreen({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    final definition = achievement.definition;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          'ACHIEVEMENT',
          style: AppTypography.sectionHeader.copyWith(
            fontSize: 13,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: AppDivider(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroCard(achievement: achievement),
            const SizedBox(height: AppSpacing.base),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(
                    label: 'Requirement',
                    value: achievement.criteriaLabel,
                  ),
                  const AppDivider(),
                  _DetailRow(
                    label: 'Current Progress',
                    value: '${achievement.progress}',
                  ),
                  const AppDivider(),
                  _DetailRow(
                    label: 'Target',
                    value: '${definition.targetValue}',
                  ),
                  const AppDivider(),
                  _DetailRow(label: 'Reward', value: achievement.rewardLabel),
                  const AppDivider(),
                  _DetailRow(label: 'Status', value: achievement.statusLabel),
                  if (achievement.unlockedAt != null) ...[
                    const AppDivider(),
                    _DetailRow(
                      label: 'Unlocked',
                      value: _formatDate(achievement.unlockedAt!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _HeroCard extends StatelessWidget {
  final AchievementProgressModel achievement;

  const _HeroCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final definition = achievement.definition;
    final unlocked = achievement.status == AchievementDisplayStatus.unlocked;

    return AppCard(
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            color: unlocked ? AppColors.acid : AppColors.paperAlt,
            alignment: Alignment.center,
            child: Icon(
              achievementIcon(definition),
              size: 44,
              color: unlocked ? AppColors.ink : AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            definition.name,
            style: AppTypography.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            definition.description,
            style: AppTypography.bodyMuted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.base),
          LinearProgressIndicator(
            value: definition.targetValue == 0
                ? 0
                : (achievement.progress / definition.targetValue).clamp(
                    0.0,
                    1.0,
                  ),
            minHeight: 7,
            color: unlocked ? AppColors.acidPressed : AppColors.ink,
            backgroundColor: AppColors.paperBorder,
            borderRadius: BorderRadius.zero,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(achievement.progressLabel, style: AppTypography.monoStrong),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(label, style: AppTypography.labelMuted),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

IconData achievementIcon(AchievementDefinitionEntity definition) {
  final reference = definition.iconReference?.toLowerCase();
  if (reference != null) {
    if (reference.contains('fire') || reference.contains('streak')) {
      return Icons.local_fire_department;
    }
    if (reference.contains('group') || reference.contains('social')) {
      return Icons.groups_outlined;
    }
    if (reference.contains('trophy') || reference.contains('milestone')) {
      return Icons.emoji_events_outlined;
    }
    if (reference.contains('workout') || reference.contains('fitness')) {
      return Icons.fitness_center;
    }
  }

  return switch (definition.category) {
    AchievementCategory.workout => Icons.fitness_center,
    AchievementCategory.streak => Icons.local_fire_department,
    AchievementCategory.social => Icons.groups_outlined,
    AchievementCategory.milestone => Icons.emoji_events_outlined,
  };
}
