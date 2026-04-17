import 'package:flutter/material.dart';

import '../../../core/entities/workout-plan-entity.dart';
import '../../../infra/repository-locator.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-divider.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../model/workout-models.dart';
import '../view-model/active-session-view-model.dart';

class ActiveSessionScreen extends StatefulWidget {
  final WorkoutPlanEntity plan;
  final SessionMode mode;

  const ActiveSessionScreen({
    super.key,
    required this.plan,
    this.mode = SessionMode.guided,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  late final ActiveSessionViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ActiveSessionViewModel(
      plan: widget.plan,
      mode: widget.mode,
      logRepo: RepositoryLocator.instance.workoutLog,
      profileRepo: RepositoryLocator.instance.profile,
      txnRepo: RepositoryLocator.instance.screenTimeTransaction,
    );
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final ok = await _confirmExit();
          if (ok && context.mounted) Navigator.pop(context);
        }
      },
      child: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          if (_vm.isSessionComplete) {
            return _CompletedView(vm: _vm, planTitle: widget.plan.title);
          }
          return Scaffold(
            backgroundColor: AppColors.paper,
            appBar: AppBar(
              backgroundColor: AppColors.paper,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              title: Text(
                widget.plan.title.toUpperCase(),
                style: AppTypography.sectionHeader.copyWith(fontSize: 13, letterSpacing: 2),
              ),
              leading: IconButton(
                icon: const Icon(Icons.close, color: AppColors.ink),
                onPressed: () async {
                  if (await _confirmExit() && context.mounted) Navigator.pop(context);
                },
              ),
              actions: [
                if (widget.mode == SessionMode.guided)
                  IconButton(
                    icon: Icon(
                      _vm.status == ActiveSessionStatus.paused
                          ? Icons.play_arrow
                          : Icons.pause,
                      color: AppColors.ink,
                    ),
                    onPressed: _vm.pauseOrResume,
                  ),
                AppButton.ghost(
                  'Done',
                  onPressed: _vm.markAllComplete,
                ),
              ],
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: AppDivider(),
              ),
            ),
            body: widget.mode == SessionMode.guided
                ? _GuidedBody(vm: _vm)
                : _ManualBody(vm: _vm),
          );
        },
      ),
    );
  }

  Future<bool> _confirmExit() async {
    if (_vm.isSessionComplete) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: const RoundedRectangleBorder(),
        title: Text('Quit Workout?', style: AppTypography.heading),
        content: Text(
          'Your progress will be lost. Are you sure?',
          style: AppTypography.body,
        ),
        actions: [
          AppButton.ghost(
            'Keep Going',
            onPressed: () => Navigator.pop(context, false),
          ),
          AppButton.destructive(
            'Quit',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ── Guided mode body ──────────────────────────────────────────────────────────

class _GuidedBody extends StatelessWidget {
  final ActiveSessionViewModel vm;
  const _GuidedBody({required this.vm});

  @override
  Widget build(BuildContext context) {
    final ex = vm.currentExercise;

    if (ex == null) return const Center(child: Text('Session complete'));

    return Column(
      children: [
        LinearProgressIndicator(
          value: vm.overallProgress,
          minHeight: 4,
          backgroundColor: AppColors.paperBorder,
          color: AppColors.ink,
          borderRadius: BorderRadius.zero,
        ),

        if (vm.status == ActiveSessionStatus.resting)
          _RestOverlay(vm: vm)
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    ex.exerciseName,
                    style: AppTypography.title.copyWith(fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set ${vm.setIndex + 1} of ${vm.totalSetsForCurrent}',
                    style: AppTypography.labelMuted,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  _SetInfo(exercise: ex),

                  const SizedBox(height: AppSpacing.xl),

                  Text(
                    _formatTime(vm.elapsedSeconds),
                    style: AppTypography.monoStrong.copyWith(
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('elapsed', style: AppTypography.labelMuted),
                  const SizedBox(height: AppSpacing.xl),

                  AppButton.primary(
                    'Complete Set',
                    onPressed: vm.completeCurrentSet,
                    width: 220,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton.ghost(
                    'Skip',
                    onPressed: vm.skipCurrentSet,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _RestOverlay extends StatelessWidget {
  final ActiveSessionViewModel vm;
  const _RestOverlay({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.self_improvement, size: 64, color: AppColors.inkMuted),
            const SizedBox(height: AppSpacing.base),
            Text('Rest', style: AppTypography.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${vm.restCountdown}s',
              style: AppTypography.monoStrong.copyWith(fontSize: 48),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.ghost('Skip Rest', onPressed: vm.completeCurrentSet),
          ],
        ),
      ),
    );
  }
}

class _SetInfo extends StatelessWidget {
  final WorkoutPlanExercise exercise;
  const _SetInfo({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (exercise.reps != null) parts.add('${exercise.reps} reps');
    if (exercise.durationSeconds != null) {
      parts.add('${exercise.durationSeconds}s');
    }
    if (exercise.weightKg != null) {
      parts.add('${exercise.weightKg} kg');
    }
    if (exercise.distanceKm != null) {
      parts.add('${exercise.distanceKm} km');
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.base),
      color: AppColors.paperAlt,
      child: Text(
        parts.join('  ·  '),
        style: AppTypography.monoStrong.copyWith(fontSize: 20),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Manual mode body ──────────────────────────────────────────────────────────

class _ManualBody extends StatelessWidget {
  final ActiveSessionViewModel vm;
  const _ManualBody({required this.vm});

  @override
  Widget build(BuildContext context) {
    final plan = vm.plan;

    return Column(
      children: [
        LinearProgressIndicator(
          value: vm.overallProgress,
          minHeight: 4,
          backgroundColor: AppColors.paperBorder,
          color: AppColors.ink,
          borderRadius: BorderRadius.zero,
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: plan.exercises.length,
            itemBuilder: (context, i) {
              final ex = plan.exercises[i];
              final isComplete = i < vm.setCompletions.length &&
                  vm.setCompletions[i].every((s) => s);

              return _ManualExerciseTile(
                exercise: ex,
                isComplete: isComplete,
                onMarkDone: () => vm.markExerciseDone(i),
                setCompletions: i < vm.setCompletions.length
                    ? vm.setCompletions[i]
                    : [],
                onToggleSet: (setIdx) {
                  vm.toggleSet(i, setIdx);
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: AppButton.primary(
            'Finish Session',
            onPressed: vm.overallProgress > 0 ? vm.markAllComplete : null,
            width: double.infinity,
          ),
        ),
      ],
    );
  }
}

class _ManualExerciseTile extends StatelessWidget {
  final WorkoutPlanExercise exercise;
  final bool isComplete;
  final List<bool> setCompletions;
  final VoidCallback onMarkDone;
  final ValueChanged<int> onToggleSet;

  const _ManualExerciseTile({
    required this.exercise,
    required this.isComplete,
    required this.setCompletions,
    required this.onMarkDone,
    required this.onToggleSet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isComplete ? AppColors.paperAlt : AppColors.paper,
        border: Border.all(
          color: isComplete ? AppColors.ink : AppColors.paperBorder,
          width: isComplete ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isComplete ? AppColors.ink : AppColors.inkMuted,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  exercise.exerciseName,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: isComplete ? TextDecoration.lineThrough : null,
                    color: isComplete ? AppColors.inkMuted : AppColors.ink,
                  ),
                ),
              ),
              if (!isComplete)
                AppButton.ghost(
                  'Done',
                  onPressed: onMarkDone,
                ),
            ],
          ),
          if (!isComplete) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              children: List.generate(exercise.sets, (i) {
                final done = i < setCompletions.length && setCompletions[i];
                return GestureDetector(
                  onTap: () => onToggleSet(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    color: done ? AppColors.ink : AppColors.paperAlt,
                    child: Center(
                      child: Text(
                        'S${i + 1}',
                        style: AppTypography.monoStrong.copyWith(
                          fontSize: 11,
                          color: done ? AppColors.paper : AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Completed view ────────────────────────────────────────────────────────────

class _CompletedView extends StatefulWidget {
  final ActiveSessionViewModel vm;
  final String planTitle;

  const _CompletedView({required this.vm, required this.planTitle});

  @override
  State<_CompletedView> createState() => _CompletedViewState();
}

class _CompletedViewState extends State<_CompletedView> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    // Defer until after the current build frame completes — calling saveSession()
    // synchronously in initState fires notifyListeners() while ListenableBuilder
    // is still rebuilding, which triggers a !_dirty assertion.
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSave());
  }

  Future<void> _autoSave() async {
    await widget.vm.saveSession();
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                color: AppColors.acid,
                child: const Icon(Icons.emoji_events, size: 40, color: AppColors.ink),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Workout Complete!', style: AppTypography.title),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.planTitle,
                style: AppTypography.labelMuted,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!_saved)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                    ),
                    const SizedBox(width: 8),
                    Text('Saving session...', style: AppTypography.body),
                  ],
                )
              else ...[
                _StatRow(
                  icon: Icons.timer_outlined,
                  label: 'Duration',
                  value: _formatMinutes(
                      (vm.elapsedSeconds / 60).ceil().clamp(1, 9999)),
                ),
                const SizedBox(height: AppSpacing.sm),
                _StatRow(
                  icon: Icons.phone_android,
                  label: 'Earned',
                  value: vm.earnedMinutes > 0
                      ? '+${_formatMinutes(vm.earnedMinutes)} screen time'
                      : 'Configure in Settings',
                ),
                if (vm.error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    vm.error!,
                    style: AppTypography.body.copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.xxl),
              AppButton.primary(
                'Back to Workouts',
                onPressed: () => Navigator.pop(context),
                width: 220,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      color: AppColors.paperAlt,
      child: Row(
        children: [
          Icon(icon, color: AppColors.ink, size: 20),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.labelMuted),
              Text(value, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
