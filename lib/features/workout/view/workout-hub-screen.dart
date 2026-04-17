import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/workout-plan-entity.dart';
import '../../../infra/repository-locator.dart';
import '../../../main.dart';
import '../../../shared/design/atoms/app-badge.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/molecules/app-card.dart';
import '../../../shared/design/organisms/app-empty-state.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../../../shared/utils/duration-estimator.dart';
import '../../../shared/utils/week-helper.dart';
import '../view-model/workout-hub-view-model.dart';
import 'exercise-library-screen.dart';

class WorkoutHubScreen extends StatefulWidget {
  const WorkoutHubScreen({super.key});

  @override
  State<WorkoutHubScreen> createState() => _WorkoutHubScreenState();
}

class _WorkoutHubScreenState extends State<WorkoutHubScreen>
    with SingleTickerProviderStateMixin {
  late final WorkoutHubViewModel _vm;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final userId = Supabase.instance.client.auth.currentUser!.id;
    _vm = WorkoutHubViewModel(
      userId: userId,
      repo: RepositoryLocator.instance.workoutPlan,
      profileRepo: RepositoryLocator.instance.profile,
    );
    _tabController = TabController(length: 3, vsync: this);
    _vm.loadPlans();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text('WORKOUTS', style: AppTypography.sectionHeader.copyWith(fontSize: 13, letterSpacing: 2)),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Plans'),
            Tab(text: 'Library'),
            Tab(text: 'AI Generated'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PlansTab(vm: _vm),
          const ExerciseLibraryScreen(),
          _AiGeneratedTab(vm: _vm),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) {
          if (_tabController.index != 0) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/workout-builder');
              if (result == true) _vm.loadPlans();
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text('New Plan', style: AppTypography.label.copyWith(color: AppColors.ink, fontSize: 13)),
          );
        },
      ),
    );
  }
}

// ── Plans tab ─────────────────────────────────────────────────────────────────

class _PlansTab extends StatelessWidget {
  final WorkoutHubViewModel vm;
  const _PlansTab({required this.vm});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (vm.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.ink));
        }
        if (vm.error != null) {
          return AppEmptyState(
            title: 'Something went wrong',
            body: vm.error!,
            primaryLabel: 'Retry',
            onPrimary: vm.loadPlans,
            icon: Icons.error_outline,
          );
        }
        if (vm.plans.isEmpty) {
          return AppEmptyState(
            title: 'No workout plans yet',
            body: 'Create your first plan to start earning screen time.',
            primaryLabel: 'Create Plan',
            onPrimary: () async {
              final result = await Navigator.pushNamed(context, '/workout-builder');
              if (result == true) vm.loadPlans();
            },
            icon: Icons.fitness_center_outlined,
          );
        }
        return RefreshIndicator(
          color: AppColors.ink,
          onRefresh: vm.loadPlans,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, 100),
            itemCount: vm.plans.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PlanCard(
                plan: vm.plans[i],
                onEdit: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    '/workout-builder',
                    arguments: {'planId': vm.plans[i].id},
                  );
                  if (result == true) vm.loadPlans();
                },
                onStart: () => Navigator.pushNamed(context, '/active-session', arguments: vm.plans[i]),
                onDelete: () => _confirmDelete(context, vm, vm.plans[i]),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WorkoutHubViewModel vm, WorkoutPlanEntity plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Plan', style: AppTypography.heading),
        content: Text('Delete "${plan.title}"? This cannot be undone.', style: AppTypography.body),
        actions: [
          AppButton.ghost('Cancel', onPressed: () => Navigator.pop(context, false)),
          const SizedBox(width: 8),
          AppButton.destructive('Delete', onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (confirmed == true) await vm.deletePlan(plan.id);
  }
}

class _PlanCard extends StatelessWidget {
  final WorkoutPlanEntity plan;
  final VoidCallback onEdit;
  final VoidCallback onStart;
  final VoidCallback onDelete;

  const _PlanCard({required this.plan, required this.onEdit, required this.onStart, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final estimate = DurationEstimator.formatEstimate(
      plan.exercises,
      {for (final e in plan.exercises) e.exerciseId: ExerciseMeasurement.repsWeight},
    );

    return AppCard(
      onTap: onEdit,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(plan.title, style: AppTypography.heading.copyWith(fontSize: 15)),
              ),
              if (plan.source == WorkoutSource.aiGenerated) ...[
                const AppBadge.acid('AI'),
                const SizedBox(width: 8),
              ],
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                color: AppColors.paper,
                shape: const RoundedRectangleBorder(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit', style: AppTypography.body),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: AppTypography.body.copyWith(color: AppColors.error)),
                  ),
                ],
                child: const Icon(Icons.more_vert, size: 20, color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: AppSpacing.base,
            runSpacing: 4,
            children: [
              _InfoRow(icon: Icons.fitness_center, label: '${plan.exercises.length} exercise${plan.exercises.length == 1 ? '' : 's'}'),
              if (estimate.isNotEmpty) _InfoRow(icon: Icons.timer_outlined, label: estimate),
              if (plan.scheduledDays.isNotEmpty)
                _InfoRow(icon: Icons.calendar_today, label: WeekHelper.formatScheduledDays(plan.scheduledDays)),
            ],
          ),
          const SizedBox(height: 12),
          AppButton.primary('Start', onPressed: onStart, width: double.infinity, icon: Icons.play_arrow),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.inkMuted),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.labelMuted),
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
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (vm.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.ink));
        }

        if (vm.isVip) {
          return AppEmptyState(
            title: 'AI Generated Workouts',
            body: 'Coming soon. We are training the model on your training history.',
            secondaryLabel: 'Open Beta Generator',
            onSecondary: () => appCoordinator.showAiGeneration(),
            icon: Icons.auto_awesome_outlined,
          );
        }

        // Free user — upsell
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: AppColors.acid, width: 3)),
                ),
                child: AppEmptyState(
                  title: 'AI Generated Workouts',
                  body: 'Personalised plans generated for you based on your history and goals. Available on VIP.',
                  primaryLabel: 'Buy VIP',
                  onPrimary: () => Navigator.pushNamed(context, '/subscription'),
                  icon: Icons.auto_awesome_outlined,
                  accentBorder: false,
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              _VipFeatureList(),
            ],
          ),
        );
      },
    );
  }
}

class _VipFeatureList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const features = [
      'AI-generated workout plans',
      'Advanced progress analytics',
      'Expanded exercise library',
      'Priority support',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('VIP INCLUDES', style: AppTypography.sectionHeader),
        const SizedBox(height: 8),
        ...features.map(
          (f) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(width: 6, height: 6, color: AppColors.acid),
                const SizedBox(width: 10),
                Text(f, style: AppTypography.body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
