import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/workout-plan-entity.dart';
import '../../../infra/repository-locator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../shared/design/atoms/app-badge.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-nav-icon.dart';
import '../../../shared/design/atoms/app-status-pill.dart';
import '../../../shared/design/atoms/app-text.dart';
import '../../../shared/design/molecules/app-card.dart';
import '../../../shared/design/molecules/app-segmented-control.dart';
import '../../../shared/design/organisms/app-dialog.dart';
import '../../../shared/design/organisms/app-scaffold.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-radii.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/utils/duration-estimator.dart';
import '../view-model/workout-hub-view-model.dart';
import 'exercise-library-screen.dart';

class WorkoutHubScreen extends StatefulWidget {
  final WorkoutHubViewModel? viewModel;
  final Widget? libraryScreen;

  const WorkoutHubScreen({super.key, this.viewModel, this.libraryScreen});

  @override
  State<WorkoutHubScreen> createState() => _WorkoutHubScreenState();
}

class _WorkoutHubScreenState extends State<WorkoutHubScreen>
    with SingleTickerProviderStateMixin {
  late final WorkoutHubViewModel _vm;
  late final TabController _tabController;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    if (widget.viewModel != null) {
      _vm = widget.viewModel!;
    } else {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      _vm = WorkoutHubViewModel(
        userId: userId,
        repo: RepositoryLocator.instance.workoutPlan,
        profileRepo: RepositoryLocator.instance.profile,
      );
    }
    _tabController = TabController(length: 3, vsync: this);
    _vm.loadPlans();
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_ownsViewModel) _vm.dispose();
    super.dispose();
  }

  Future<void> _openBuilder() async {
    final result = await Navigator.pushNamed(context, '/workout-builder');
    if (result == true) _vm.loadPlans();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppText.title(l10n.workouts),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: ListenableBuilder(
                listenable: _tabController,
                builder: (context, _) => AppSegmentedControl<int>(
                  options: [
                    AppSegmentOption(value: 0, label: l10n.workoutMyPlans),
                    AppSegmentOption(value: 1, label: l10n.workoutLibrary),
                    AppSegmentOption(value: 2, label: l10n.workoutAi),
                  ],
                  selected: _tabController.index,
                  onChanged: _tabController.animateTo,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _PlansTab(vm: _vm, onCreate: _openBuilder),
                  widget.libraryScreen ?? const ExerciseLibraryScreen(),
                  _AiGeneratedTab(vm: _vm),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) {
          if (_tabController.index != 0) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _openBuilder,
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.workoutNewPlan),
          );
        },
      ),
    );
  }
}

// ── Plans tab ─────────────────────────────────────────────────────────────────

class _PlansTab extends StatelessWidget {
  final WorkoutHubViewModel vm;
  final VoidCallback onCreate;

  const _PlansTab({required this.vm, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.nashaatPalette;

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (vm.isLoading) {
          return Center(
            child: CircularProgressIndicator(color: palette.accent),
          );
        }

        if (vm.error != null) {
          return _HubStateCard(
            icon: Icons.error_outline,
            title: l10n.genericError,
            body: l10n.workoutCouldNotLoad,
            actionLabel: l10n.next,
            onAction: vm.loadPlans,
          );
        }

        if (vm.plans.isEmpty) {
          return _HubStateCard(
            icon: AppNavGlyph.crossedOars,
            title: l10n.workoutNoPlansTitle,
            body: Theme.of(context).platform == TargetPlatform.iOS
                ? l10n.workoutNoPlansScreenTime
                : l10n.workoutNoPlansTraining,
            actionLabel: l10n.workoutNewPlan,
            onAction: onCreate,
          );
        }

        final nextPlan = _recommendedPlan(vm.plans);
        return RefreshIndicator(
          color: palette.accent,
          onRefresh: vm.loadPlans,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              112,
            ),
            children: [
              _NextWorkoutCard(
                plan: nextPlan,
                onStart: () => _startPlan(context, nextPlan),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppText.heading(l10n.workoutYourPlans),
              const SizedBox(height: AppSpacing.sm),
              ...vm.plans.map(
                (plan) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _PlanCard(
                    plan: plan,
                    onEdit: () => _editPlan(context, vm, plan),
                    onStart: () => _startPlan(context, plan),
                    onDelete: () => _confirmDelete(context, vm, plan),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editPlan(
    BuildContext context,
    WorkoutHubViewModel vm,
    WorkoutPlanEntity plan,
  ) async {
    final result = await Navigator.pushNamed(
      context,
      '/workout-builder',
      arguments: {'planId': plan.id},
    );
    if (result == true) vm.loadPlans();
  }

  Future<void> _startPlan(BuildContext context, WorkoutPlanEntity plan) async {
    await Navigator.pushNamed(context, '/active-session', arguments: plan);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WorkoutHubViewModel vm,
    WorkoutPlanEntity plan,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: AppText.heading(l10n.delete),
      content: AppText.body(l10n.workoutDeleteConfirmation(plan.title)),
      actions: [
        AppButton.ghost(
          l10n.cancel,
          onPressed: () => Navigator.pop(context, false),
        ),
        AppButton.destructive(
          l10n.delete,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (confirmed == true) await vm.deletePlan(plan.id);
  }
}

WorkoutPlanEntity _recommendedPlan(List<WorkoutPlanEntity> plans) {
  final today = DateTime.now().weekday;
  return plans.firstWhere(
    (plan) => plan.scheduledDays.contains(today),
    orElse: () => plans.first,
  );
}

class _NextWorkoutCard extends StatelessWidget {
  final WorkoutPlanEntity plan;
  final VoidCallback onStart;

  const _NextWorkoutCard({required this.plan, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isToday = plan.scheduledDays.contains(DateTime.now().weekday);
    final estimate = _estimate(plan);
    return AppCard.standard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppNavIcon(
                glyph: AppNavGlyph.crossedOars,
                selected: true,
                size: 34,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: AppText.section(l10n.workoutNextWorkout)),
              AppStatusPill(
                label: isToday ? l10n.workoutToday : l10n.workoutRecommended,
                tone: isToday ? AppStatusTone.accent : AppStatusTone.calm,
                showDot: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppText.title(plan.title),
          if (estimate.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            AppText.mono(estimate),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton.primary(
            l10n.startWorkout,
            onPressed: onStart,
            width: double.infinity,
            icon: Icons.play_arrow,
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final WorkoutPlanEntity plan;
  final VoidCallback onEdit;
  final VoidCallback onStart;
  final VoidCallback onDelete;

  const _PlanCard({
    required this.plan,
    required this.onEdit,
    required this.onStart,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.nashaatPalette;
    final estimate = _estimate(plan);
    final isToday = plan.scheduledDays.contains(DateTime.now().weekday);

    return AppCard.standard(
      onTap: onEdit,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: AppText.heading(plan.title)),
              if (plan.source == WorkoutSource.aiGenerated) ...[
                AppBadge('AI', tone: AppStatusTone.reward),
                const SizedBox(width: AppSpacing.sm),
              ],
              PopupMenuButton<String>(
                tooltip: l10n.workoutPlanMenu,
                icon: Icon(Icons.more_horiz, color: palette.textMuted),
                color: palette.card,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadii.control,
                ),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: AppText.body(l10n.edit)),
                  PopupMenuItem(
                    value: 'delete',
                    child: AppText.body(l10n.delete, color: palette.dangerText),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppText.mono(
            _planSummary(l10n, plan, estimate),
            color: palette.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          _ScheduleDots(days: plan.scheduledDays),
          const SizedBox(height: AppSpacing.md),
          isToday
              ? AppButton.primary(
                  l10n.startWorkout,
                  onPressed: onStart,
                  width: double.infinity,
                  icon: Icons.play_arrow,
                )
              : AppButton.ghost(
                  l10n.startWorkout,
                  onPressed: onStart,
                  width: double.infinity,
                  icon: Icons.play_arrow,
                ),
        ],
      ),
    );
  }
}

class _ScheduleDots extends StatelessWidget {
  final List<int> days;

  const _ScheduleDots({required this.days});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final today = DateTime.now().weekday;
    const sundayFirst = [7, 1, 2, 3, 4, 5, 6];
    return Semantics(
      label: 'Scheduled days',
      value: days.isEmpty ? 'None' : days.join(', '),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final weekday in sundayFirst)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 5),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: days.contains(weekday)
                      ? weekday == today
                            ? palette.accent
                            : palette.calm
                      : palette.raised,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: days.contains(weekday)
                        ? Colors.transparent
                        : palette.border,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HubStateCard extends StatelessWidget {
  final Object icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  const _HubStateCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        AppCard.flat(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              if (icon is IconData)
                Icon(icon as IconData, size: 48, color: palette.textMuted)
              else
                AppNavIcon(
                  glyph: icon as AppNavGlyph,
                  selected: true,
                  size: 52,
                ),
              const SizedBox(height: AppSpacing.md),
              AppText.heading(title, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              AppText.bodyMuted(body, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              AppButton.primary(
                actionLabel,
                onPressed: onAction,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── AI Generated tab ──────────────────────────────────────────────────────────

class _AiGeneratedTab extends StatelessWidget {
  final WorkoutHubViewModel vm;

  const _AiGeneratedTab({required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.nashaatPalette;

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (vm.isLoading) {
          return Center(
            child: CircularProgressIndicator(color: palette.accent),
          );
        }

        return ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            if (!vm.isVip)
              AppCard.reward(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 28,
                          color: palette.rewardText,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: AppText.heading(l10n.workoutAiTitle)),
                        const AppBadge('VIP', tone: AppStatusTone.reward),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppText.body(l10n.workoutAiBody),
                    const SizedBox(height: AppSpacing.md),
                    _FeatureRow(l10n.workoutAiPlans),
                    _FeatureRow(l10n.workoutAiAnalytics),
                    _FeatureRow(l10n.workoutAiLibrary),
                    _FeatureRow(l10n.workoutAiSupport),
                    const SizedBox(height: AppSpacing.md),
                    AppButton.reward(
                      l10n.workoutUpgradeVip,
                      onPressed: () =>
                          Navigator.pushNamed(context, '/subscription'),
                      width: double.infinity,
                    ),
                  ],
                ),
              )
            else
              AppCard.standard(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 28,
                          color: palette.accentText,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: AppText.heading(l10n.workoutAiTitle)),
                        AppStatusPill(label: 'Beta', tone: AppStatusTone.calm),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppText.heading(l10n.workoutComingSoon),
                    const SizedBox(height: AppSpacing.sm),
                    AppText.bodyMuted(l10n.workoutAiTrainingBody),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton.ghost(
                      l10n.workoutTryBeta,
                      onPressed: appCoordinator.showAiGeneration,
                      width: double.infinity,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String label;

  const _FeatureRow(this.label);

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check, size: 16, color: palette.rewardText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: AppText.body(label)),
        ],
      ),
    );
  }
}

String _estimate(WorkoutPlanEntity plan) {
  return DurationEstimator.formatEstimate(plan.exercises, {
    for (final exercise in plan.exercises)
      exercise.exerciseId: ExerciseMeasurement.repsWeight,
  });
}

String _planSummary(
  AppLocalizations l10n,
  WorkoutPlanEntity plan,
  String estimate,
) {
  if (estimate.isEmpty) return l10n.workoutExerciseCount(plan.exercises.length);
  return l10n.workoutPlanSummary(plan.exercises.length, estimate);
}
