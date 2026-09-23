import 'package:flutter/material.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/exercise-entity.dart';
import '../../../infra/repository-locator.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-divider.dart';
import '../../../shared/design/molecules/app-section-header.dart';
import '../../../shared/design/organisms/app-empty-state.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../view-model/exercise-library-view-model.dart';

/// A full-screen browsable exercise library.
///
/// When [selectionMode] is true, tapping an exercise pops the route and
/// returns the selected [ExerciseEntity].
class ExerciseLibraryScreen extends StatefulWidget {
  final bool selectionMode;

  const ExerciseLibraryScreen({super.key, this.selectionMode = false});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  late final ExerciseLibraryViewModel _vm;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm = ExerciseLibraryViewModel(repo: RepositoryLocator.instance.exercise);
    _vm.loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(),
      builder: (_) => DraggableScrollableSheet(
  expand: false,
  initialChildSize: 0.85,
  minChildSize: 0.5,
  maxChildSize: 0.95,
  builder: (context, scrollController) {
    return _FilterBottomSheet(
      vm: _vm,
      scrollController: scrollController,
    );
  },
),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(
          widget.selectionMode ? 'ADD EXERCISE' : 'EXERCISE LIBRARY',
          style: AppTypography.sectionHeader.copyWith(fontSize: 13, letterSpacing: 2),
        ),
        actions: [
          ListenableBuilder(
            listenable: _vm,
            builder: (_, child) {
             final count =
    (_vm.selectedMuscleGroup != null ? 1 : 0) +
    (_vm.selectedDifficulty != null ? 1 : 0) +
    (_vm.selectedMeasurement != null ? 1 : 0);
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    icon: const Icon(Icons.tune, color: AppColors.ink),
                    tooltip: 'Filter',
                    onPressed: _showFilterSheet,
                  ),
                  if (count > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 14,
                        height: 14,
                        color: AppColors.acid,
                        child: Center(
                          child: Text(
                            '$count',
                            style: AppTypography.mono.copyWith(fontSize: 9),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(57),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, 8),
                child: ListenableBuilder(
                  listenable: _vm,
                  builder: (context, child) => TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search exercises...',
                      hintStyle: AppTypography.labelMuted,
                      prefixIcon: const Icon(Icons.search, color: AppColors.inkMuted, size: 18),
                      suffixIcon: _vm.searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _vm.onSearchChanged('');
                              },
                              child: const Icon(Icons.clear, color: AppColors.inkMuted, size: 18),
                            )
                          : null,
                      isDense: true,
                    ),
                    onChanged: _vm.onSearchChanged,
                  ),
                ),
              ),
              const AppDivider(),
            ],
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          if (_vm.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.ink));
          }
          if (_vm.error != null) {
            return AppEmptyState(
              title: 'Something went wrong',
              body: _vm.error!,
              primaryLabel: 'Retry',
              onPrimary: _vm.loadAll,
              icon: Icons.error_outline,
            );
          }

          return _vm.exercises.isEmpty
              ? AppEmptyState(
                  title: 'No exercises found',
                body: _vm.searchQuery.isNotEmpty ||
        _vm.selectedMuscleGroup != null ||
        _vm.selectedDifficulty != null ||
        _vm.selectedMeasurement != null ||
        _vm.selectedSort != null
    ? 'Try adjusting your filters.'
    : 'No exercises in the library yet.',
                  icon: Icons.search_off,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.base,
                  ),
                  itemCount: _vm.exercises.length,
                  itemBuilder: (context, i) {
                    final exercise = _vm.exercises[i];
                    return _ExerciseCard(
                      exercise: exercise,
                      selectionMode: widget.selectionMode,
                      onTap: () {
                        if (widget.selectionMode) {
                          Navigator.pop(context, exercise);
                        } else {
                          Navigator.pushNamed(
                            context,
                            '/exercise-detail',
                            arguments: exercise,
                          );
                        }
                      },
                    );
                  },
                );
        },
      ),
    );
  }
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────

class _FilterBottomSheet extends StatelessWidget {
  final ExerciseLibraryViewModel vm;
  final ScrollController scrollController;

  const _FilterBottomSheet({
    required this.vm,
    required this.scrollController,
  });
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final hasActiveFilter =
            vm.selectedMuscleGroup != null ||
            vm.selectedDifficulty != null ||
            vm.selectedMeasurement != null ||
            vm.selectedSort != null;

        return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.lg,
            AppSpacing.base,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    'FILTER',
                    style: AppTypography.sectionHeader,
                  ),
                  const Spacer(),

                  if (hasActiveFilter)
                    AppButton.ghost(
                      'Clear all',
                      onPressed: vm.clearFiltersOnly,
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),
              const AppDivider(),
              const SizedBox(height: AppSpacing.base),

              // Muscle Group
              AppSectionHeader(
                'Muscle Group',
                padding: EdgeInsets.zero,
              ),

              const SizedBox(height: AppSpacing.sm),

              if (vm.availableMuscleGroups.isEmpty)
                Text(
                  'No data yet',
                  style: AppTypography.labelMuted,
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: vm.availableMuscleGroups.map((g) {
                    final selected =
                        vm.selectedMuscleGroup?.toLowerCase() ==
                            g.toLowerCase();

                    return _FlatChip(
                      label: g,
                      selected: selected,
                      onTap: () =>
                          vm.setMuscleGroup(selected ? null : g),
                    );
                  }).toList(),
                ),

              const SizedBox(height: AppSpacing.lg),

              // Difficulty
              AppSectionHeader(
                'Difficulty',
                padding: EdgeInsets.zero,
              ),

              const SizedBox(height: AppSpacing.sm),

              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: DifficultyLevel.values.map((d) {
                  final selected = vm.selectedDifficulty == d;

                  final label = switch (d) {
                    DifficultyLevel.easy => 'Easy',
                    DifficultyLevel.medium => 'Medium',
                    DifficultyLevel.hard => 'Hard',
                  };

                  return _FlatChip(
                    label: label,
                    selected: selected,
                    onTap: () =>
                        vm.setDifficulty(selected ? null : d),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Measurement
              AppSectionHeader(
                'Measurement',
                padding: EdgeInsets.zero,
              ),

              const SizedBox(height: AppSpacing.sm),

              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: ExerciseMeasurement.values.map((m) {
                  final selected = vm.selectedMeasurement == m;

                  final label = switch (m) {
                    ExerciseMeasurement.repsWeight =>
                      'Reps + Weight',
                    ExerciseMeasurement.timeDistance =>
                      'Time + Distance',
                    ExerciseMeasurement.timeOnly =>
                      'Time Only',
                    ExerciseMeasurement.repsOnly =>
                      'Reps Only',
                  };

                  return _FlatChip(
                    label: label,
                    selected: selected,
                    onTap: () =>
                        vm.setMeasurement(selected ? null : m),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Sort
              AppSectionHeader(
                'Sort by',
                padding: EdgeInsets.zero,
              ),

              const SizedBox(height: AppSpacing.sm),

              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: ExerciseSort.values.map((sort) {
                  final selected = vm.selectedSort == sort;

                  final label = switch (sort) {
                    ExerciseSort.nameAsc => 'Name A-Z',
                    ExerciseSort.nameDesc => 'Name Z-A',
                    ExerciseSort.difficultyAsc => 'Easy → Hard',
                    ExerciseSort.difficultyDesc => 'Hard → Easy',
                  };

                  return _FlatChip(
                    label: label,
                    selected: selected,
                    onTap: () =>
                        vm.setSort(selected ? null : sort),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        )
        );
      },
    );
  }
}

class _FlatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FlatChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.paper,
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.paperBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            color: selected ? AppColors.paper : AppColors.ink,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ── Exercise card ─────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final ExerciseEntity exercise;
  final bool selectionMode;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.exercise,
    required this.selectionMode,
    required this.onTap,
  });

  @override
Widget build(BuildContext context) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.paperBorder),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          _ExerciseIcon(exercise: exercise),
          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    ...exercise.muscleGroups.take(2).map(
                      (m) => _InlineChip(label: m),
                    ),

                    _DifficultyInlineChip(
                      level: exercise.difficultyLevel,
                    ),

                    _MeasurementInlineChip(
                      measurement: exercise.measurementType,
                    ),
                  ],
                ),
              ],
            ),
          ),

          Icon(
            selectionMode
                ? Icons.add_circle_outline
                : Icons.chevron_right,
            color: AppColors.inkMuted,
            size: 20,
          ),
        ],
      ),
    ),
  );
}
}

class _ExerciseIcon extends StatelessWidget {
  final ExerciseEntity exercise;

  const _ExerciseIcon({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final imageUrl = exercise.mediaLink;

    return Container(
      width: 48,
      height: 48,
      color: AppColors.paperAlt,
      child: imageUrl != null && imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _fallbackIcon();
              },
            )
          : _fallbackIcon(),
    );
  }

  Widget _fallbackIcon() {
    return Icon(
      _muscleIcon(exercise.muscleGroups.firstOrNull ?? ''),
      color: AppColors.ink,
      size: 22,
    );
  }

  IconData _muscleIcon(String muscle) {
    final m = muscle.toLowerCase();

    if (m.contains('chest')) return Icons.fitness_center;

    if (m.contains('back') || m.contains('lat')) {
      return Icons.accessibility_new;
    }

    if (m.contains('leg') ||
        m.contains('quad') ||
        m.contains('hamstring')) {
      return Icons.directions_run;
    }

    if (m.contains('shoulder') || m.contains('delt')) {
      return Icons.sports_gymnastics;
    }

    if (m.contains('core') || m.contains('ab')) {
      return Icons.straighten;
    }

    if (m.contains('cardio') || m.contains('run')) {
      return Icons.directions_run;
    }

    return Icons.fitness_center;
  }
}

class _InlineChip extends StatelessWidget {
  final String label;
  const _InlineChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      color: AppColors.paperAlt,
      child: Text(label, style: AppTypography.mono.copyWith(fontSize: 10)),
    );
  }
}

class _DifficultyInlineChip extends StatelessWidget {
  final DifficultyLevel level;
  const _DifficultyInlineChip({required this.level});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (level) {
      DifficultyLevel.easy => (AppColors.acid, 'Easy'),
      DifficultyLevel.medium => (AppColors.signal, 'Medium'),
      DifficultyLevel.hard => (AppColors.errorMuted, 'Hard'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      color: color,
      child: Text(
        label,
        style: AppTypography.mono.copyWith(fontSize: 10, color: AppColors.ink),
      ),
    );
  }
}

class _MeasurementInlineChip extends StatelessWidget {
  final ExerciseMeasurement measurement;

  const _MeasurementInlineChip({
    required this.measurement,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (measurement) {
      ExerciseMeasurement.repsWeight => 'Reps + Weight',
      ExerciseMeasurement.timeDistance => 'Time + Distance',
      ExerciseMeasurement.timeOnly => 'Time',
      ExerciseMeasurement.repsOnly => 'Reps',
    };

    return _InlineChip(label: label);
  }
}