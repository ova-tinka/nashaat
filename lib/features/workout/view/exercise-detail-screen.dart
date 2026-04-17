import 'package:flutter/material.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/exercise-entity.dart';
import '../../../shared/design/atoms/app-divider.dart';
import '../../../shared/design/molecules/app-section-header.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final ExerciseEntity exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.paper,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            title: Text(
              exercise.name.toUpperCase(),
              style: AppTypography.sectionHeader.copyWith(fontSize: 13, letterSpacing: 2),
            ),
            expandedHeight: 180,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.inkSoft,
                child: const Center(
                  child: Icon(
                    Icons.fitness_center,
                    size: 80,
                    color: AppColors.paperBorder,
                  ),
                ),
              ),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: AppDivider(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.base),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _DifficultyBadge(level: exercise.difficultyLevel),
                    _MeasurementBadge(type: exercise.measurementType),
                    ...exercise.muscleGroups.map(
                      (m) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        color: AppColors.paperAlt,
                        child: Text(m, style: AppTypography.label.copyWith(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                if (exercise.description != null &&
                    exercise.description!.isNotEmpty) ...[
                  AppSectionHeader('About', padding: EdgeInsets.zero),
                  const SizedBox(height: AppSpacing.sm),
                  Text(exercise.description!, style: AppTypography.body.copyWith(color: AppColors.inkMuted)),
                  const SizedBox(height: AppSpacing.lg),
                ],

                if (exercise.steps.isNotEmpty) ...[
                  AppSectionHeader('How to do it', padding: EdgeInsets.zero),
                  const SizedBox(height: AppSpacing.md),
                  ...exercise.steps.asMap().entries.map(
                        (entry) => _StepRow(
                          number: entry.key + 1,
                          text: entry.value,
                        ),
                      ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final DifficultyLevel level;
  const _DifficultyBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final (bg, label) = switch (level) {
      DifficultyLevel.easy => (AppColors.acid, 'Easy'),
      DifficultyLevel.medium => (AppColors.signal, 'Medium'),
      DifficultyLevel.hard => (AppColors.errorMuted, 'Hard'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: bg,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bar_chart, size: 14, color: AppColors.ink),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.label.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurementBadge extends StatelessWidget {
  final ExerciseMeasurement type;
  const _MeasurementBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      ExerciseMeasurement.repsOnly => 'Reps',
      ExerciseMeasurement.repsWeight => 'Reps + Weight',
      ExerciseMeasurement.timeOnly => 'Time',
      ExerciseMeasurement.timeDistance => 'Time + Distance',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: AppColors.paperAlt,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: AppColors.inkMuted),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.label.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int number;
  final String text;

  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            color: AppColors.ink,
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: AppTypography.monoStrong.copyWith(
                fontSize: 12,
                color: AppColors.paper,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text, style: AppTypography.body),
            ),
          ),
        ],
      ),
    );
  }
}
