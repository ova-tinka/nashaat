import 'package:flutter/material.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/exercise-entity.dart';
import '../../../infra/repository-locator.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectionMode ? 'Add Exercise' : 'Exercise Library'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search exercises…',
              leading: const Icon(Icons.search),
              trailing: [
                ListenableBuilder(
                  listenable: _vm,
                  builder: (_, __) => _vm.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _vm.onSearchChanged('');
                          },
                        )
                      : const SizedBox.shrink(),
                ),
              ],
              onChanged: _vm.onSearchChanged,
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          if (_vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_vm.error != null) {
            return _ErrorState(
              message: _vm.error!,
              onRetry: _vm.loadAll,
            );
          }

          return Column(
            children: [
              _FilterRow(vm: _vm),
              Expanded(
                child: _vm.exercises.isEmpty
                    ? _EmptyState(hasFilters: _vm.searchQuery.isNotEmpty ||
                        _vm.selectedMuscleGroup != null ||
                        _vm.selectedDifficulty != null)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
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
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Filter row ────────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final ExerciseLibraryViewModel vm;
  const _FilterRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = vm.selectedMuscleGroup != null ||
        vm.selectedDifficulty != null;

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          if (hasActiveFilter)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                label: const Text('Clear'),
                avatar: const Icon(Icons.close, size: 16),
                onPressed: vm.clearFilters,
              ),
            ),
          _MuscleGroupMenu(vm: vm),
          const SizedBox(width: 6),
          ...DifficultyLevel.values.map((d) {
            final selected = vm.selectedDifficulty == d;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(_difficultyLabel(d)),
                selected: selected,
                onSelected: (_) =>
                    vm.setDifficulty(selected ? null : d),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _difficultyLabel(DifficultyLevel d) => switch (d) {
        DifficultyLevel.easy => 'Easy',
        DifficultyLevel.medium => 'Medium',
        DifficultyLevel.hard => 'Hard',
      };
}

class _MuscleGroupMenu extends StatelessWidget {
  final ExerciseLibraryViewModel vm;
  const _MuscleGroupMenu({required this.vm});

  @override
  Widget build(BuildContext context) {
    final groups = vm.availableMuscleGroups;
    final selected = vm.selectedMuscleGroup;

    return PopupMenuButton<String>(
      initialValue: selected,
      onSelected: (value) =>
          vm.setMuscleGroup(value == selected ? null : value),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: '',
          child: Text('All Muscles'),
        ),
        ...groups.map(
          (g) => PopupMenuItem(value: g, child: Text(g)),
        ),
      ],
      child: FilterChip(
        label: Text(selected ?? 'Muscle Group'),
        avatar: const Icon(Icons.expand_more, size: 18),
        selected: selected != null,
        onSelected: (_) {},
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _ExerciseIcon(exercise: exercise),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        ...exercise.muscleGroups.take(3).map(
                              (m) => _Chip(
                                label: m,
                                color: cs.secondaryContainer,
                                textColor: cs.onSecondaryContainer,
                              ),
                            ),
                        _DifficultyChip(level: exercise.difficultyLevel),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                selectionMode
                    ? Icons.add_circle_outline
                    : Icons.chevron_right,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        _muscleIcon(exercise.muscleGroups.firstOrNull ?? ''),
        color: cs.onPrimaryContainer,
      ),
    );
  }

  IconData _muscleIcon(String muscle) {
    final m = muscle.toLowerCase();
    if (m.contains('chest')) return Icons.fitness_center;
    if (m.contains('back') || m.contains('lat')) return Icons.accessibility_new;
    if (m.contains('leg') || m.contains('quad') || m.contains('hamstring')) {
      return Icons.directions_run;
    }
    if (m.contains('shoulder') || m.contains('delt')) return Icons.sports_gymnastics;
    if (m.contains('core') || m.contains('ab')) return Icons.straighten;
    if (m.contains('cardio') || m.contains('run')) return Icons.directions_run;
    if (m.contains('bicep')) return Icons.sports_handball;
    if (m.contains('tricep')) return Icons.sports_handball;
    return Icons.fitness_center;
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Chip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: textColor),
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final DifficultyLevel level;
  const _DifficultyChip({required this.level});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (color, label) = switch (level) {
      DifficultyLevel.easy => (Colors.green.shade100, 'Easy'),
      DifficultyLevel.medium => (cs.primaryContainer, 'Medium'),
      DifficultyLevel.hard => (cs.errorContainer, 'Hard'),
    };
    final textColor = switch (level) {
      DifficultyLevel.easy => Colors.green.shade800,
      DifficultyLevel.medium => cs.onPrimaryContainer,
      DifficultyLevel.hard => cs.onErrorContainer,
    };

    return _Chip(label: label, color: color, textColor: textColor);
  }
}

// ── States ────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No exercises match your filters' : 'No exercises yet',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
