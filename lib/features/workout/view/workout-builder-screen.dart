import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/exercise-entity.dart';
import '../../../infra/repository-locator.dart';
import '../../../shared/utils/week-helper.dart';
import '../model/workout-models.dart';
import '../view-model/workout-builder-view-model.dart';
import 'exercise-library-screen.dart';

class WorkoutBuilderScreen extends StatefulWidget {
  final String? editPlanId;

  const WorkoutBuilderScreen({super.key, this.editPlanId});

  @override
  State<WorkoutBuilderScreen> createState() => _WorkoutBuilderScreenState();
}

class _WorkoutBuilderScreenState extends State<WorkoutBuilderScreen> {
  late final WorkoutBuilderViewModel _vm;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _vm = WorkoutBuilderViewModel(
      planRepo: RepositoryLocator.instance.workoutPlan,
      exerciseRepo: RepositoryLocator.instance.exercise,
    );

    if (widget.editPlanId != null) {
      _vm.loadForEdit(widget.editPlanId!).then((_) {
        _titleController.text = _vm.title;
        _descController.text = _vm.description;
      });
    }

    _titleController.addListener(() {
      _vm.setTitleFromController(_titleController.text);
    });
    _descController.addListener(() {
      _vm.setDescriptionFromController(_descController.text);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.editPlanId != null ? 'Edit Plan' : 'New Plan'),
            actions: [
              if (_vm.durationEstimate.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      avatar: const Icon(Icons.timer_outlined, size: 16),
                      label: Text(_vm.durationEstimate),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(
                  onPressed: _vm.isValid && !_vm.isSaving ? _handleSave : null,
                  child: _vm.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                if (_vm.error != null)
                  _ErrorBanner(
                    message: _vm.error!,
                    onDismiss: _vm.clearError,
                  ),

                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Plan title *',
                    hintText: 'e.g. Push Day, Full Body HIIT',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Title is required' : null,
                ),
                const SizedBox(height: 12),

                // Description
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 20),

                // Session size
                _SessionSizeSelector(vm: _vm),
                const SizedBox(height: 20),

                // Weekday schedule
                _WeekdaySelector(vm: _vm),
                const SizedBox(height: 20),

                // Exercises header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Exercises',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addExercise,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),

                if (_vm.entries.isEmpty)
                  _EmptyExercises(onAdd: _addExercise)
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _vm.entries.length,
                    onReorder: _vm.reorderExercise,
                    buildDefaultDragHandles: false,
                    itemBuilder: (context, index) {
                      return _ExerciseEntryCard(
                        key: ValueKey(_vm.entries[index].exercise.id + index.toString()),
                        index: index,
                        entry: _vm.entries[index],
                        vm: _vm,
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addExercise() async {
    final exercise = await Navigator.push<ExerciseEntity>(
      context,
      MaterialPageRoute(
        builder: (_) => const ExerciseLibraryScreen(selectionMode: true),
      ),
    );
    if (exercise != null) {
      _vm.addExercise(exercise);
    }
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final result = await _vm.save();
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.editPlanId != null
              ? 'Plan updated successfully'
              : 'Plan created successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
  }
}

// ── Session size selector ─────────────────────────────────────────────────────

class _SessionSizeSelector extends StatelessWidget {
  final WorkoutBuilderViewModel vm;
  const _SessionSizeSelector({required this.vm});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session size',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          'Determines how much screen time this workout earns.',
          style: tt.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        SegmentedButton<SessionSize>(
          segments: const [
            ButtonSegment(
              value: SessionSize.small,
              icon: Icon(Icons.fitness_center, size: 16),
              label: Text('Small'),
            ),
            ButtonSegment(
              value: SessionSize.big,
              icon: Icon(Icons.local_fire_department, size: 16),
              label: Text('Big  ×2'),
            ),
          ],
          selected: {vm.sessionSize},
          onSelectionChanged: (s) => vm.setSessionSize(s.first),
        ),
      ],
    );
  }
}

// ── Weekday selector ──────────────────────────────────────────────────────────

class _WeekdaySelector extends StatelessWidget {
  final WorkoutBuilderViewModel vm;
  const _WeekdaySelector({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Schedule',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (vm.scheduledDays.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              WeekHelper.formatScheduledDays(vm.scheduledDays),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
        Wrap(
          spacing: 6,
          children: List.generate(7, (i) {
            final day = i + 1;
            final selected = vm.scheduledDays.contains(day);
            return FilterChip(
              label: Text(WeekHelper.shortDayLabel(day)),
              selected: selected,
              onSelected: (_) => vm.toggleDay(day),
              visualDensity: VisualDensity.compact,
            );
          }),
        ),
      ],
    );
  }
}

// ── Exercise entry card ───────────────────────────────────────────────────────

class _ExerciseEntryCard extends StatelessWidget {
  final int index;
  final BuilderEntry entry;
  final WorkoutBuilderViewModel vm;

  const _ExerciseEntryCard({
    required super.key,
    required this.index,
    required this.entry,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.drag_handle, color: cs.outlineVariant),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.exercise.name,
                    style: tt.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: cs.error),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => vm.removeExercise(index),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _EntryFields(index: index, entry: entry, vm: vm),
          ],
        ),
      ),
    );
  }
}

class _EntryFields extends StatelessWidget {
  final int index;
  final BuilderEntry entry;
  final WorkoutBuilderViewModel vm;

  const _EntryFields({
    required this.index,
    required this.entry,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final measurement = entry.exercise.measurementType;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _NumberField(
          label: 'Sets',
          value: entry.sets,
          min: 1,
          max: 20,
          onChanged: (v) {
            entry.sets = v;
            vm.updateEntry(index, entry);
          },
        ),
        if (measurement == ExerciseMeasurement.repsOnly ||
            measurement == ExerciseMeasurement.repsWeight)
          _NumberField(
            label: 'Reps',
            value: entry.reps ?? 10,
            min: 1,
            max: 999,
            onChanged: (v) {
              entry.reps = v;
              vm.updateEntry(index, entry);
            },
          ),
        if (measurement == ExerciseMeasurement.repsWeight)
          _DecimalField(
            label: 'Weight (kg)',
            value: entry.weightKg ?? 0,
            onChanged: (v) {
              entry.weightKg = v;
              vm.updateEntry(index, entry);
            },
          ),
        if (measurement == ExerciseMeasurement.timeOnly ||
            measurement == ExerciseMeasurement.timeDistance)
          _NumberField(
            label: 'Duration (s)',
            value: entry.durationSeconds ?? 30,
            min: 1,
            max: 9999,
            onChanged: (v) {
              entry.durationSeconds = v;
              vm.updateEntry(index, entry);
            },
          ),
        if (measurement == ExerciseMeasurement.timeDistance)
          _DecimalField(
            label: 'Distance (km)',
            value: entry.distanceKm ?? 0,
            onChanged: (v) {
              entry.distanceKm = v;
              vm.updateEntry(index, entry);
            },
          ),
        _NumberField(
          label: 'Rest (s)',
          value: entry.restSeconds ?? 60,
          min: 0,
          max: 600,
          onChanged: (v) {
            entry.restSeconds = v;
            vm.updateEntry(index, entry);
          },
        ),
      ],
    );
  }
}

class _NumberField extends StatefulWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(_NumberField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _ctrl.text != widget.value.toString()) {
      _ctrl.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: TextFormField(
        controller: _ctrl,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (s) {
          final v = int.tryParse(s);
          if (v != null && v >= widget.min && v <= widget.max) {
            widget.onChanged(v);
          }
        },
      ),
    );
  }
}

class _DecimalField extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _DecimalField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_DecimalField> createState() => _DecimalFieldState();
}

class _DecimalFieldState extends State<_DecimalField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.value == 0 ? '' : widget.value.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: TextFormField(
        controller: _ctrl,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        onChanged: (s) {
          final v = double.tryParse(s);
          if (v != null && v >= 0) widget.onChanged(v);
        },
      ),
    );
  }
}

// ── Misc ──────────────────────────────────────────────────────────────────────

class _EmptyExercises extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyExercises({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.add_circle_outline, size: 48, color: cs.outlineVariant),
          const SizedBox(height: 12),
          const Text('No exercises added yet', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onAdd, child: const Text('Add Exercise')),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(color: cs.onErrorContainer)),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            color: cs.onErrorContainer,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
