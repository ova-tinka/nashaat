import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/exercise-entity.dart';
import '../../../infra/repository-locator.dart';
import '../../../shared/design/atoms/app-badge.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-chip.dart';
import '../../../shared/design/atoms/app-divider.dart';
import '../../../shared/design/molecules/app-section-header.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
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
            body: Center(child: CircularProgressIndicator(color: AppColors.ink)),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.paper,
          appBar: AppBar(
            backgroundColor: AppColors.paper,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            title: Text(
              widget.editPlanId != null ? 'EDIT PLAN' : 'NEW PLAN',
              style: AppTypography.sectionHeader.copyWith(fontSize: 13, letterSpacing: 2),
            ),
            actions: [
              if (_vm.durationEstimate.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: AppBadge(_vm.durationEstimate),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: AppButton.primary(
                  'Save',
                  isLoading: _vm.isSaving,
                  onPressed: _vm.isValid && !_vm.isSaving ? _handleSave : null,
                ),
              ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: AppColors.paperBorder),
            ),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, AppSpacing.sm, AppSpacing.base, 120,
              ),
              children: [
                if (_vm.error != null)
                  _ErrorBanner(message: _vm.error!, onDismiss: _vm.clearError),

                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Plan title *',
                    hintText: 'e.g. Push Day, Full Body HIIT',
                  ),
                  style: AppTypography.body,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Title is required' : null,
                ),
                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                  style: AppTypography.body,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.lg),

                _SessionSizeSelector(vm: _vm),
                const SizedBox(height: AppSpacing.lg),

                _WeekdaySelector(vm: _vm),
                const SizedBox(height: AppSpacing.lg),

                Row(
                  children: [
                    Expanded(
                      child: AppSectionHeader('Exercises', padding: EdgeInsets.zero),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton.ghost(
                      'Add',
                      icon: Icons.add,
                      onPressed: _addExercise,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session size', style: AppTypography.heading.copyWith(fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          'Determines how much screen time this workout earns.',
          style: AppTypography.labelMuted,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            AppSelectChip(
              label: 'Small',
              selected: vm.sessionSize == SessionSize.small,
              onTap: () => vm.setSessionSize(SessionSize.small),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppSelectChip(
              label: 'Big  x2',
              selected: vm.sessionSize == SessionSize.big,
              onTap: () => vm.setSessionSize(SessionSize.big),
            ),
          ],
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
        Text('Schedule', style: AppTypography.heading.copyWith(fontSize: 14)),
        const SizedBox(height: 6),
        if (vm.scheduledDays.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              WeekHelper.formatScheduledDays(vm.scheduledDays),
              style: AppTypography.labelMuted,
            ),
          ),
        Wrap(
          spacing: 6,
          children: List.generate(7, (i) {
            final day = i + 1;
            return AppDayChip(
              label: WeekHelper.shortDayLabel(day),
              selected: vm.scheduledDays.contains(day),
              onTap: () => vm.toggleDay(day),
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.paperBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.sm,
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(right: AppSpacing.sm),
                    child: Icon(Icons.drag_handle, color: AppColors.inkMuted, size: 20),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.exercise.name,
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.error),
                  onPressed: () => vm.removeExercise(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          const AppDivider(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _EntryFields(index: index, entry: entry, vm: vm),
          ),
        ],
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
          labelStyle: AppTypography.labelMuted,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
        ),
        style: AppTypography.mono,
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
          labelStyle: AppTypography.labelMuted,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
        ),
        style: AppTypography.mono,
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

// ── Empty / error ─────────────────────────────────────────────────────────────

class _EmptyExercises extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyExercises({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.paperBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.add_circle_outline, size: 40, color: AppColors.inkMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No exercises added yet',
            style: AppTypography.labelMuted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton.ghost('Add Exercise', onPressed: onAdd),
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
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base, vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorMuted,
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: AppTypography.body.copyWith(color: AppColors.error)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, color: AppColors.error, size: 16),
          ),
        ],
      ),
    );
  }
}
