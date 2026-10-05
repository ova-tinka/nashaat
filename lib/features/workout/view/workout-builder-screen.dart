import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/exercise-entity.dart';
import '../../../infra/repository-locator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/design/atoms/app-badge.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-chip.dart';
import '../../../shared/design/atoms/app-status-pill.dart';
import '../../../shared/design/atoms/app-text.dart';
import '../../../shared/design/molecules/app-banner.dart';
import '../../../shared/design/molecules/app-card.dart';
import '../../../shared/design/organisms/app-scaffold.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/utils/week-helper.dart';
import '../model/workout-models.dart';
import '../view-model/workout-builder-view-model.dart';
import 'exercise-library-screen.dart';

WorkoutBuilderViewModel? workoutBuilderDraft;

class WorkoutBuilderScreen extends StatefulWidget {
  final String? editPlanId;
  final WorkoutBuilderViewModel? viewModel;

  const WorkoutBuilderScreen({super.key, this.editPlanId, this.viewModel});

  @override
  State<WorkoutBuilderScreen> createState() => _WorkoutBuilderScreenState();
}

class _WorkoutBuilderScreenState extends State<WorkoutBuilderScreen> {
  late final WorkoutBuilderViewModel _vm;
  late final bool _ownsViewModel;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    if (widget.viewModel != null) {
      _vm = widget.viewModel!;
    } else if (widget.editPlanId == null && workoutBuilderDraft != null) {
      _vm = workoutBuilderDraft!;
    } else {
      _vm = WorkoutBuilderViewModel(
        planRepo: RepositoryLocator.instance.workoutPlan,
        exerciseRepo: RepositoryLocator.instance.exercise,
      );
      if (widget.editPlanId == null) workoutBuilderDraft = _vm;
    }

    if (widget.editPlanId != null) {
      _vm.loadForEdit(widget.editPlanId!).then((_) {
        if (!mounted) return;
        _titleController.text = _vm.title;
        _descController.text = _vm.description;
      });
    } else {
      _titleController.text = _vm.title;
      _descController.text = _vm.description;
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
    if (_ownsViewModel &&
        (widget.editPlanId != null || workoutBuilderDraft != _vm)) {
      _vm.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.isLoading) {
          return AppScaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: context.nashaatPalette.accent,
              ),
            ),
          );
        }

        return AppScaffold(
          body: SafeArea(
            child: Column(
              children: [
                _BuilderHeader(
                  title: widget.editPlanId != null
                      ? l10n.builderEditPlan
                      : l10n.builderNewPlan,
                  estimate: _vm.durationEstimate,
                  onClose: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.xl,
                      ),
                      children: [
                        if (_vm.error != null)
                          _ErrorBanner(
                            message: _vm.error!,
                            onDismiss: _vm.clearError,
                          ),
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: l10n.builderPlanTitle,
                            hintText: l10n.builderPlanTitleHint,
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          validator: (v) => (v?.trim().isEmpty ?? true)
                              ? l10n.builderPlanTitle
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _descController,
                          decoration: InputDecoration(
                            labelText: l10n.builderDescriptionOptional,
                          ),
                          maxLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (Platform.isIOS) ...[
                          _SessionSizeSelector(vm: _vm),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        _WeekdaySelector(vm: _vm),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: AppText.heading(l10n.builderExercises),
                            ),
                            AppButton.ghost(
                              l10n.builderAddExercise,
                              icon: Icons.add,
                              onPressed: _addExercise,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: AppStatusPill(
                            label: l10n.builderExerciseCount(
                              _vm.entries.length,
                            ),
                            tone: AppStatusTone.calm,
                          ),
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
                                key: ValueKey(
                                  _vm.entries[index].exercise.id +
                                      index.toString(),
                                ),
                                index: index,
                                entry: _vm.entries[index],
                                vm: _vm,
                                onChangeExercise: _changeExercise,
                                showError: _vm.error != null,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                _BuilderFooter(
                  count: l10n.builderExerciseCount(_vm.entries.length),
                  estimate: _vm.durationEstimate,
                  isSaving: _vm.isSaving,
                  onSave: _handleSave,
                  saveLabel: l10n.builderSavePlan,
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

  Future<void> _changeExercise(int index) async {
    final exercise = await Navigator.push<ExerciseEntity>(
      context,
      MaterialPageRoute(
        builder: (_) => const ExerciseLibraryScreen(selectionMode: true),
      ),
    );

    if (exercise != null) _vm.changeExercise(index, exercise);
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    final result = await _vm.save();
    if (result != null && mounted) {
      if (widget.editPlanId == null) {
        workoutBuilderDraft = null;
      }
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.editPlanId != null
                ? l10n.builderPlanUpdated
                : l10n.builderPlanCreated,
          ),
        ),
      );
      Navigator.pop(context, true);
    }
  }
}

class _BuilderHeader extends StatelessWidget {
  final String title;
  final String estimate;
  final VoidCallback onClose;

  const _BuilderHeader({
    required this.title,
    required this.estimate,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.nashaatPalette.border),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonLabel,
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: AppText.heading(title)),
          if (estimate.isNotEmpty) AppBadge(estimate, tone: AppStatusTone.calm),
        ],
      ),
    );
  }
}

class _BuilderFooter extends StatelessWidget {
  final String count;
  final String estimate;
  final bool isSaving;
  final VoidCallback onSave;
  final String saveLabel;

  const _BuilderFooter({
    required this.count,
    required this.estimate,
    required this.isSaving,
    required this.onSave,
    required this.saveLabel,
  });

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        viewInsets > 0 ? viewInsets + AppSpacing.sm : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.nashaatPalette.background,
        border: Border(top: BorderSide(color: context.nashaatPalette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.body(count),
                if (estimate.isNotEmpty) AppText.mono(estimate),
              ],
            ),
          ),
          SizedBox(
            width: 188,
            child: AppButton.primary(
              saveLabel,
              isLoading: isSaving,
              onPressed: isSaving ? null : onSave,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Session size selector ─────────────────────────────────────────────────────

class _SessionSizeSelector extends StatelessWidget {
  final WorkoutBuilderViewModel vm;
  const _SessionSizeSelector({required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.heading(l10n.builderSessionSize),
        const SizedBox(height: 4),
        AppText.bodyMuted(l10n.builderSessionSizeBody),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            AppSelectChip(
              label: l10n.builderSmall,
              selected: vm.sessionSize == SessionSize.small,
              onTap: () => vm.setSessionSize(SessionSize.small),
              tone: AppStatusTone.calm,
            ),
            const SizedBox(width: AppSpacing.sm),
            AppSelectChip(
              label: l10n.builderBig,
              selected: vm.sessionSize == SessionSize.big,
              onTap: () => vm.setSessionSize(SessionSize.big),
              tone: AppStatusTone.reward,
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.heading(l10n.builderSchedule),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final day in const [7, 1, 2, 3, 4, 5, 6])
              AppSelectChip(
                label: WeekHelper.shortDayLabel(day),
                selected: vm.scheduledDays.contains(day),
                onTap: () => vm.toggleDay(day),
                tone: AppStatusTone.calm,
              ),
          ],
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
  final Future<void> Function(int index) onChangeExercise;
  final bool showError;

  const _ExerciseEntryCard({
    required super.key,
    required this.index,
    required this.entry,
    required this.vm,
    required this.onChangeExercise,
    required this.showError,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.nashaatPalette;
    final invalid = showError && _entryHasValidationError(entry);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AppCard.standard(
        border: invalid ? Border.all(color: palette.dangerText) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.sm,
                      ),
                      child: Icon(
                        Icons.drag_handle,
                        color: palette.textMuted,
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(child: AppText.heading(entry.exercise.name)),
                  IconButton(
                    tooltip: l10n.builderSwapExercise,
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    onPressed: () => onChangeExercise(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.builderRemoveExercise,
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: palette.dangerText,
                    ),
                    onPressed: () => vm.removeExercise(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _EntryFields(
                index: index,
                entry: entry,
                vm: vm,
                showError: showError,
              ),
            ),
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
  final bool showError;

  const _EntryFields({
    required this.index,
    required this.entry,
    required this.vm,
    required this.showError,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final measurement = entry.exercise.measurementType;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _NumberField(
          label: l10n.builderSets,
          value: entry.sets,
          min: 1,
          max: 20,
          showError: showError && entry.sets < 1,
          onChanged: (v) {
            entry.sets = v;
            vm.updateEntry(index, entry);
          },
        ),
        if (measurement == ExerciseMeasurement.repsOnly ||
            measurement == ExerciseMeasurement.repsWeight)
          _NumberField(
            label: l10n.builderReps,
            value: entry.reps ?? 10,
            min: 1,
            max: 999,
            showError: showError && (entry.reps ?? 0) < 1,
            onChanged: (v) {
              entry.reps = v;
              vm.updateEntry(index, entry);
            },
          ),
        if (measurement == ExerciseMeasurement.repsWeight)
          _DecimalField(
            label: l10n.builderWeight,
            value: entry.weightKg ?? 0,
            showError: showError && (entry.weightKg ?? 0) <= 0,
            onChanged: (v) {
              entry.weightKg = v;
              vm.updateEntry(index, entry);
            },
          ),
        if (measurement == ExerciseMeasurement.timeOnly ||
            measurement == ExerciseMeasurement.timeDistance)
          _NumberField(
            label: l10n.builderDuration,
            value: entry.durationSeconds ?? 30,
            min: 1,
            max: 9999,
            showError: showError && (entry.durationSeconds ?? 0) < 1,
            onChanged: (v) {
              entry.durationSeconds = v;
              vm.updateEntry(index, entry);
            },
          ),
        if (measurement == ExerciseMeasurement.timeDistance)
          _DecimalField(
            label: l10n.builderDistance,
            value: entry.distanceKm ?? 0,
            showError: showError && (entry.distanceKm ?? 0) <= 0,
            onChanged: (v) {
              entry.distanceKm = v;
              vm.updateEntry(index, entry);
            },
          ),
        _NumberField(
          label: l10n.builderRest,
          value: entry.restSeconds ?? 60,
          min: 1,
          max: 600,
          showError: showError && (entry.restSeconds ?? 0) < 1,
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
  final bool showError;

  const _NumberField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.showError = false,
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
    final l10n = AppLocalizations.of(context)!;
    final palette = context.nashaatPalette;
    return SizedBox(
      width: 90,
      child: TextFormField(
        controller: _ctrl,
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: palette.textMuted),
          errorText: widget.showError ? l10n.builderInvalidValue : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          isDense: true,
        ),
        style: GoogleFonts.jetBrainsMono(
          color: palette.textPrimary,
          fontSize: 13,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (s) {
          final v = int.tryParse(s);
          if (v != null && v >= widget.min && v <= widget.max) {
            widget.onChanged(v);
          } else {
            widget.onChanged(0);
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
  final bool showError;

  const _DecimalField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.showError = false,
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
    final l10n = AppLocalizations.of(context)!;
    final palette = context.nashaatPalette;
    return SizedBox(
      width: 100,
      child: TextFormField(
        controller: _ctrl,
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: palette.textMuted),
          errorText: widget.showError ? l10n.builderInvalidValue : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          isDense: true,
        ),
        style: GoogleFonts.jetBrainsMono(
          color: palette.textPrimary,
          fontSize: 13,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        onChanged: (s) {
          final v = double.tryParse(s);
          if (v != null && v >= 0) {
            widget.onChanged(v);
          } else {
            widget.onChanged(0.0);
          }
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
    final l10n = AppLocalizations.of(context)!;
    final palette = context.nashaatPalette;
    return AppCard.flat(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Icon(Icons.add_circle_outline, size: 40, color: palette.accentText),
          const SizedBox(height: AppSpacing.md),
          AppText.bodyMuted(
            l10n.builderNoExercises,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton.ghost(l10n.builderAddExercise, onPressed: onAdd),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppBanner(
        message: message,
        tone: AppStatusTone.attention,
        icon: Icons.error_outline,
        action: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonLabel,
          onPressed: onDismiss,
          icon: const Icon(Icons.close, size: 18),
        ),
      ),
    );
  }
}

bool _entryHasValidationError(BuilderEntry entry) {
  if (entry.sets <= 0 || (entry.restSeconds ?? 0) <= 0) return true;
  switch (entry.exercise.measurementType) {
    case ExerciseMeasurement.repsOnly:
      return (entry.reps ?? 0) <= 0;
    case ExerciseMeasurement.repsWeight:
      return (entry.reps ?? 0) <= 0 || (entry.weightKg ?? 0) <= 0;
    case ExerciseMeasurement.timeOnly:
      return (entry.durationSeconds ?? 0) <= 0;
    case ExerciseMeasurement.timeDistance:
      return (entry.durationSeconds ?? 0) <= 0 || (entry.distanceKm ?? 0) <= 0;
  }
}
