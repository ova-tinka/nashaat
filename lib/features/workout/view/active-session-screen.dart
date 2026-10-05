import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/workout-plan-entity.dart';
import '../../../infra/repository-locator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-status-pill.dart';
import '../../../shared/design/atoms/app-text.dart';
import '../../../shared/design/molecules/app-card.dart';
import '../../../shared/design/molecules/app-banner.dart';
import '../../../shared/design/organisms/app-dialog.dart';
import '../../../shared/design/molecules/app-progress-bar.dart';
import '../../../shared/design/molecules/app-timer-ring.dart';
import '../../../shared/design/organisms/app-scaffold.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-radii.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../model/workout-models.dart';
import '../view-model/active-session-view-model.dart';

class ActiveSessionScreen extends StatefulWidget {
  final WorkoutPlanEntity plan;
  final SessionMode mode;
  final ActiveSessionViewModel? viewModel;

  const ActiveSessionScreen({
    super.key,
    required this.plan,
    this.mode = SessionMode.guided,
    this.viewModel,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  late final ActiveSessionViewModel _vm;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _vm =
        widget.viewModel ??
        ActiveSessionViewModel(
          plan: widget.plan,
          mode: widget.mode,
          logRepo: RepositoryLocator.instance.workoutLog,
          profileRepo: RepositoryLocator.instance.profile,
          achievementRepo: RepositoryLocator.instance.achievement,
        );
    if (_ownsViewModel) _vm.initialize();
  }

  @override
  void dispose() {
    if (_ownsViewModel) _vm.dispose();
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

          return AppScaffold(
            body: SafeArea(
              child: Column(
                children: [
                  _SessionHeader(
                    title: widget.plan.title,
                    onClose: () async {
                      if (await _confirmExit() && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    onDone: _vm.isStartingServerSession
                        ? null
                        : _vm.markAllComplete,
                  ),
                  Expanded(
                    child: widget.mode == SessionMode.guided
                        ? _GuidedBody(vm: _vm)
                        : _ManualBody(vm: _vm),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _confirmExit() async {
    if (_vm.isSessionComplete) return true;
    final l10n = AppLocalizations.of(context)!;
    final result = await AppDialog.show<bool>(
      context: context,
      title: AppText.heading(l10n.activeQuitTitle),
      content: AppText.body(l10n.activeQuitBody),
      actions: [
        AppButton.ghost(
          l10n.activeKeepGoing,
          onPressed: () => Navigator.pop(context, false),
        ),
        AppButton.destructive(
          l10n.activeQuit,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    return result ?? false;
  }
}

class _SessionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final VoidCallback? onDone;

  const _SessionHeader({
    required this.title,
    required this.onClose,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 10),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: IconButton(
              tooltip: l10n.back,
              onPressed: onClose,
              icon: const Icon(Icons.close),
              padding: EdgeInsets.zero,
            ),
          ),
          Expanded(
            child: AppText.heading(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 64,
            child: TextButton(
              onPressed: onDone,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(64, 44),
              ),
              child: Text(
                l10n.activeFinish,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.nashaatPalette.accentText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Guided mode ──────────────────────────────────────────────────────────────

class _GuidedBody extends StatelessWidget {
  final ActiveSessionViewModel vm;

  const _GuidedBody({required this.vm});

  @override
  Widget build(BuildContext context) {
    final ex = vm.currentExercise;
    final l10n = AppLocalizations.of(context)!;
    final palette = context.nashaatPalette;

    if (ex == null) {
      return Center(child: AppText.bodyMuted(l10n.activeWorkoutComplete));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: _SessionProgress(vm: vm),
        ),
        if (vm.status == ActiveSessionStatus.resting)
          _RestOverlay(vm: vm)
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppText.section(
                    'EXERCISE ${vm.exerciseIndex + 1} OF ${vm.totalExercises}',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppText.hero(
                    ex.exerciseName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SessionMetricPills(vm: vm, exercise: ex),
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: AppTimerRing(
                      progress: vm.overallProgress,
                      size: 224,
                      strokeWidth: 14,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(vm.elapsedSeconds),
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  color: palette.textPrimary,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'JetBrains Mono',
                                ),
                          ),
                          const SizedBox(height: 2),
                          AppText.bodyMuted(l10n.activeElapsed),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppText.body(
                    '${vm.plan.sessionSize == SessionSize.big ? 'Big' : 'Small'} workout · earns screen time when you finish',
                    textAlign: TextAlign.center,
                    color: palette.textBody,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton.primary(
                    l10n.activeCompleteSet,
                    onPressed: vm.completeCurrentSet,
                    width: double.infinity,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton.ghost(
                    l10n.activeSkip,
                    onPressed: vm.skipCurrentSet,
                    width: double.infinity,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }
}

class _RestOverlay extends StatelessWidget {
  final ActiveSessionViewModel vm;

  const _RestOverlay({required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.nashaatPalette;
    final nextEx = vm.currentExercise;
    final isNewExercise = vm.setIndex == 0;
    final nextLabel = nextEx == null
        ? null
        : isNewExercise
        ? nextEx.exerciseName
        : '${l10n.activeSetProgress(vm.setIndex + 1, vm.totalSetsForCurrent)} · ${nextEx.exerciseName}';

    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 300),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppStatusPill(
                label: l10n.activeRest,
                tone: AppStatusTone.calm,
                showDot: true,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${vm.restCountdown}s',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: palette.textPrimary,
                  fontSize: 52,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
              if (nextLabel != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppCard.standard(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Row(
                    children: [
                      Icon(
                        Icons.fitness_center_rounded,
                        size: 20,
                        color: palette.calmText,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText.label(l10n.activeUpNext),
                            const SizedBox(height: 2),
                            AppText.body(
                              nextLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton.ghost(
                l10n.activeSkipRest,
                onPressed: vm.skipRest,
                width: 230,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionProgress extends StatelessWidget {
  final ActiveSessionViewModel vm;

  const _SessionProgress({required this.vm});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Row(
      children: List.generate(vm.totalExercises, (index) {
        final completed = index < vm.exerciseIndex;
        final current = index == vm.exerciseIndex;
        final currentProgress = vm.totalSetsForCurrent == 0
            ? 0.0
            : (vm.setIndex / vm.totalSetsForCurrent).clamp(0.0, 1.0);
        return Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              end: index == vm.totalExercises - 1 ? 0 : AppSpacing.sm,
            ),
            child: ClipRRect(
              borderRadius: AppRadii.sm,
              child: Stack(
                children: [
                  ColoredBox(
                    color: palette.raised,
                    child: const SizedBox(height: 8, width: double.infinity),
                  ),
                  FractionallySizedBox(
                    widthFactor: completed
                        ? 1
                        : current
                        ? currentProgress.clamp(0.08, 1.0)
                        : 0,
                    child: ColoredBox(
                      color: palette.accent,
                      child: const SizedBox(height: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _SessionMetricPills extends StatelessWidget {
  final ActiveSessionViewModel vm;
  final WorkoutPlanExercise exercise;

  const _SessionMetricPills({required this.vm, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (exercise.reps != null) parts.add('${exercise.reps} reps');
    if (exercise.durationSeconds != null) {
      parts.add('${exercise.durationSeconds}s');
    }
    if (exercise.weightKg != null) parts.add('${exercise.weightKg} kg');
    if (exercise.distanceKm != null) parts.add('${exercise.distanceKm} km');

    final setLabel = 'Set ${vm.setIndex + 1} of ${vm.totalSetsForCurrent}';
    final repsLabel = parts.isEmpty ? '—' : parts.first;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _SessionMetricPill(label: setLabel, tone: AppStatusTone.calm),
        _SessionMetricPill(label: repsLabel, tone: AppStatusTone.reward),
      ],
    );
  }
}

class _SessionMetricPill extends StatelessWidget {
  final String label;
  final AppStatusTone tone;

  const _SessionMetricPill({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final color = switch (tone) {
      AppStatusTone.calm => palette.calmText,
      AppStatusTone.reward => palette.rewardText,
      _ => palette.textPrimary,
    };
    final background = switch (tone) {
      AppStatusTone.calm => palette.calm.withValues(alpha: 0.16),
      AppStatusTone.reward => palette.reward.withValues(alpha: 0.12),
      _ => palette.raised,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: background, borderRadius: AppRadii.pill),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
      ),
    );
  }
}

// ── Manual mode ──────────────────────────────────────────────────────────────

class _ManualBody extends StatelessWidget {
  final ActiveSessionViewModel vm;

  const _ManualBody({required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final plan = vm.plan;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: AppProgressBar(value: vm.overallProgress),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: plan.exercises.length,
            itemBuilder: (context, i) {
              final ex = plan.exercises[i];
              final isComplete =
                  i < vm.setCompletions.length &&
                  vm.setCompletions[i].every((s) => s);

              return _ManualExerciseTile(
                exercise: ex,
                isComplete: isComplete,
                onMarkDone: () => vm.markExerciseDone(i),
                setCompletions: i < vm.setCompletions.length
                    ? vm.setCompletions[i]
                    : const [],
                onToggleSet: (setIdx) => vm.toggleSet(i, setIdx),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: AppButton.primary(
            l10n.activeFinishSession,
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
    final palette = context.nashaatPalette;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard.standard(
        backgroundColor: isComplete
            ? palette.accent.withValues(alpha: 0.08)
            : null,
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isComplete
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isComplete ? palette.accentText : palette.textMuted,
                  size: 21,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppText.body(
                    exercise.exerciseName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isComplete)
                  AppStatusPill(
                    label: l10n.activeDone,
                    tone: AppStatusTone.accent,
                    showDot: true,
                  )
                else
                  AppButton.ghost(
                    l10n.activeDone,
                    onPressed: onMarkDone,
                    width: 104,
                  ),
              ],
            ),
            if (!isComplete) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: List.generate(exercise.sets, (i) {
                  final done = i < setCompletions.length && setCompletions[i];
                  return Semantics(
                    button: true,
                    label: 'Set ${i + 1}',
                    checked: done,
                    child: GestureDetector(
                      onTap: () => onToggleSet(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 42,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: done ? palette.accent : palette.well,
                          borderRadius: AppRadii.sm,
                          border: Border.all(
                            color: done ? palette.accent : palette.border,
                          ),
                        ),
                        child: AppText.monoStrong(
                          'S${i + 1}',
                          color: done
                              ? palette.accentInk
                              : palette.textSecondary,
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

// ── Completion ceremony ──────────────────────────────────────────────────────

class _CompletedView extends StatefulWidget {
  final ActiveSessionViewModel vm;
  final String planTitle;

  const _CompletedView({required this.vm, required this.planTitle});

  @override
  State<_CompletedView> createState() => _CompletedViewState();
}

class _CompletedViewState extends State<_CompletedView> {
  bool _saved = false;
  int _revealStep = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSave());
  }

  Future<void> _autoSave() async {
    await widget.vm.initialize();
    await widget.vm.saveSession();
    if (!mounted || widget.vm.error != null) return;

    setState(() {
      _saved = true;
      _revealStep = 1;
    });
    _continueReveal();
  }

  Future<void> _continueReveal() async {
    for (var step = 2; step <= 4; step++) {
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      setState(() => _revealStep = step);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final l10n = AppLocalizations.of(context)!;
    final displayName =
        vm.profile?.username ?? vm.profile?.firstName ?? 'there';

    return AppScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText.section('${widget.planTitle.toUpperCase()} · COMPLETE'),
              const SizedBox(height: AppSpacing.lg),
              AppText.hero(
                'Strong work, $displayName',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!_saved && vm.error == null)
                _SavingState(
                  message: vm.isStartingServerSession
                      ? l10n.activeStarting
                      : l10n.activeSaving,
                )
              else if (!_saved)
                _SaveError(message: vm.error!, onRetry: _autoSave)
              else ...[
                _reveal(
                  1,
                  _StatRow(
                    icon: Icons.timer_outlined,
                    label: 'DURATION',
                    value: _formatClock(vm.elapsedSeconds),
                  ),
                ),
                _reveal(
                  2,
                  _StatRow(
                    icon: Icons.phone_android_rounded,
                    label: 'SCREEN TIME',
                    value: 'Added to your balance',
                    trailing: _earnedValue(vm, l10n),
                    trailingColor: context.nashaatPalette.accentText,
                  ),
                ),
                _reveal(
                  3,
                  _StatRow(
                    icon: Icons.circle,
                    label: 'REWARD POINTS',
                    value: 'Total ${_formatPoints(vm.pointsTotal)}',
                    trailing: vm.pointsEarned > 0
                        ? '+${vm.pointsEarned}'
                        : l10n.activeNoRewardPoints,
                    trailingColor: context.nashaatPalette.rewardText,
                  ),
                ),
                _reveal(
                  4,
                  _StatRow(
                    icon: Icons.card_membership_outlined,
                    label: 'WORKOUT STREAK',
                    value:
                        '${vm.currentStreak} days · longest ${vm.longestStreak}',
                  ),
                ),
                if (_revealStep >= 4) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppButton.primary(
                    l10n.activeThanks,
                    onPressed: () => Navigator.pop(context),
                    width: double.infinity,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _reveal(int step, Widget child) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: _revealStep >= step
          ? KeyedSubtree(key: ValueKey('revealed-$step'), child: child)
          : SizedBox(key: ValueKey('hidden-$step')),
    );
  }

  String _earnedValue(ActiveSessionViewModel vm, AppLocalizations l10n) {
    if (vm.earnedMinutes > 0) {
      return '+${_formatMinutes(vm.earnedMinutes)}';
    }
    return Platform.isIOS
        ? l10n.activeConfigureSettings
        : l10n.activeWorkoutLogged;
  }

  static String _formatClock(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  static String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  static String _formatPoints(int points) {
    final value = points.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      if (i > 0 && (value.length - i) % 3 == 0) buffer.write(',');
      buffer.write(value[i]);
    }
    return buffer.toString();
  }
}

class _SavingState extends StatelessWidget {
  final String message;

  const _SavingState({required this.message});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return AppCard.standard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: AppText.body(message, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class _SaveError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SaveError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBanner(
          message: message,
          tone: AppStatusTone.attention,
          icon: Icons.warning_amber_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton.ghost(
          AppLocalizations.of(context)!.activeRetrySave,
          onPressed: onRetry,
          width: double.infinity,
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? trailing;
  final Color? trailingColor;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.trailingColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard.standard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.raised,
                borderRadius: AppRadii.card,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  icon,
                  color: icon == Icons.circle
                      ? palette.textPrimary
                      : palette.textSecondary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.section(label),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  trailing!,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: trailingColor ?? palette.textPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
