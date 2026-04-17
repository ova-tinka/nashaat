import 'package:flutter/material.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/exercise-entity.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final ExerciseEntity exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(exercise.name),
            expandedHeight: 220,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: cs.primaryContainer,
                child: Center(
                  child: Icon(
                    Icons.fitness_center,
                    size: 96,
                    color: cs.onPrimaryContainer.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Chips row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _DifficultyBadge(level: exercise.difficultyLevel),
                    _MeasurementBadge(type: exercise.measurementType),
                    ...exercise.muscleGroups.map(
                      (m) => Chip(
                        label: Text(m),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: cs.secondaryContainer,
                        labelStyle:
                            TextStyle(color: cs.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Description
                if (exercise.description != null &&
                    exercise.description!.isNotEmpty) ...[
                  Text('About',
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    exercise.description!,
                    style: tt.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                ],

                // Steps
                if (exercise.steps.isNotEmpty) ...[
                  Text('How to do it',
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ...exercise.steps.asMap().entries.map(
                        (entry) => _StepRow(
                          number: entry.key + 1,
                          text: entry.value,
                        ),
                      ),
                  const SizedBox(height: 24),
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
    final cs = Theme.of(context).colorScheme;
    final (bg, fg, label) = switch (level) {
      DifficultyLevel.easy => (
          Colors.green.shade100,
          Colors.green.shade800,
          'Easy'
        ),
      DifficultyLevel.medium => (cs.primaryContainer, cs.onPrimaryContainer, 'Medium'),
      DifficultyLevel.hard => (cs.errorContainer, cs.onErrorContainer, 'Hard'),
    };

    return Chip(
      label: Text(label),
      backgroundColor: bg,
      labelStyle: TextStyle(color: fg, fontWeight: FontWeight.w600),
      avatar: Icon(Icons.bar_chart, size: 16, color: fg),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MeasurementBadge extends StatelessWidget {
  final ExerciseMeasurement type;
  const _MeasurementBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = switch (type) {
      ExerciseMeasurement.repsOnly => 'Reps',
      ExerciseMeasurement.repsWeight => 'Reps + Weight',
      ExerciseMeasurement.timeOnly => 'Time',
      ExerciseMeasurement.timeDistance => 'Time + Distance',
    };

    return Chip(
      label: Text(label),
      backgroundColor: cs.tertiaryContainer,
      labelStyle: TextStyle(color: cs.onTertiaryContainer),
      avatar: Icon(Icons.timer_outlined, size: 16, color: cs.onTertiaryContainer),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _StepRow extends StatelessWidget {
  final int number;
  final String text;

  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: tt.labelMedium?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text, style: tt.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}
