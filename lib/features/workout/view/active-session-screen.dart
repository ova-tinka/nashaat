import 'package:flutter/material.dart';

import '../../../core/entities/workout-plan-entity.dart';
import '../../../infra/repository-locator.dart';
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
          if (ok && mounted) Navigator.pop(context);
        }
      },
      child: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          if (_vm.isSessionComplete) {
            return _CompletedView(vm: _vm, planTitle: widget.plan.title);
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.plan.title),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () async {
                  if (await _confirmExit() && mounted) Navigator.pop(context);
                },
              ),
              actions: [
                if (widget.mode == SessionMode.guided)
                  IconButton(
                    icon: Icon(_vm.status == ActiveSessionStatus.paused
                        ? Icons.play_arrow
                        : Icons.pause),
                    onPressed: _vm.pauseOrResume,
                  ),
                TextButton(
                  onPressed: _vm.markAllComplete,
                  child: const Text('Done'),
                ),
              ],
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
        title: const Text('Quit Workout?'),
        content: const Text(
            'Your progress will be lost. Are you sure you want to quit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quit'),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ex = vm.currentExercise;

    if (ex == null) return const Center(child: Text('Session complete'));

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: vm.overallProgress,
          minHeight: 4,
          backgroundColor: cs.surfaceContainerHighest,
        ),

        if (vm.status == ActiveSessionStatus.resting)
          _RestOverlay(vm: vm)
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Exercise name
                  Text(
                    ex.exerciseName,
                    style: tt.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set ${vm.setIndex + 1} of ${vm.totalSetsForCurrent}',
                    style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),

                  // Set info
                  _SetInfo(exercise: ex),

                  const SizedBox(height: 40),

                  // Elapsed time
                  Text(
                    _formatTime(vm.elapsedSeconds),
                    style: tt.displaySmall?.copyWith(
                      fontWeight: FontWeight.w300,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('elapsed', style: tt.bodySmall),
                  const SizedBox(height: 40),

                  FilledButton(
                    onPressed: vm.completeCurrentSet,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(200, 52),
                    ),
                    child: const Text('Complete Set'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: vm.skipCurrentSet,
                    child: const Text('Skip'),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.self_improvement, size: 72, color: cs.primary),
            const SizedBox(height: 16),
            Text('Rest', style: tt.headlineMedium),
            const SizedBox(height: 8),
            Text(
              '${vm.restCountdown}s',
              style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: vm.completeCurrentSet,
              child: const Text('Skip Rest'),
            ),
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
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        parts.join('  ·  '),
        style: tt.titleLarge?.copyWith(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
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
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
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
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: vm.overallProgress > 0 ? vm.markAllComplete : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Finish Session'),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isComplete ? cs.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isComplete
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isComplete ? cs.onPrimaryContainer : cs.outlineVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    exercise.exerciseName,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration:
                          isComplete ? TextDecoration.lineThrough : null,
                      color: isComplete ? cs.onPrimaryContainer : null,
                    ),
                  ),
                ),
                if (!isComplete)
                  TextButton(
                    onPressed: onMarkDone,
                    child: const Text('Done'),
                  ),
              ],
            ),
            if (!isComplete) ...[
              const SizedBox(height: 8),
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
                      decoration: BoxDecoration(
                        color: done ? cs.primary : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'S${i + 1}',
                          style: tt.labelSmall?.copyWith(
                            color: done ? cs.onPrimary : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final vm = widget.vm;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emoji_events,
                size: 80,
                color: cs.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Workout Complete!',
                style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                widget.planTitle,
                style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              if (!_saved)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    const Text('Saving session…'),
                  ],
                )
              else ...[
                _StatTile(
                  icon: Icons.timer_outlined,
                  label: 'Duration',
                  value: _formatMinutes(
                      (vm.elapsedSeconds / 60).ceil().clamp(1, 9999)),
                ),
                const SizedBox(height: 8),
                _StatTile(
                  icon: Icons.phone_android,
                  label: 'Earned',
                  value: vm.earnedMinutes > 0
                      ? '+${_formatMinutes(vm.earnedMinutes)} screen time'
                      : 'Configure in Settings → Screen Time',
                ),
                if (vm.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    vm.error!,
                    style: TextStyle(color: cs.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
              const SizedBox(height: 40),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 48),
                ),
                child: const Text('Back to Workouts'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes} min';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
