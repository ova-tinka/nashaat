import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/workout-plan-entity.dart';
import '../../../infra/repository-locator.dart';
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
    );
    _tabController = TabController(length: 2, vsync: this);
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
      appBar: AppBar(
        title: const Text('Workouts'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Plans'),
            Tab(text: 'Exercise Library'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PlansTab(vm: _vm),
          const ExerciseLibraryScreen(),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) {
          if (_tabController.index != 0) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.pushNamed(
                context,
                '/workout-builder',
              );
              if (result == true) _vm.loadPlans();
            },
            icon: const Icon(Icons.add),
            label: const Text('New Plan'),
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
          return const Center(child: CircularProgressIndicator());
        }

        if (vm.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(vm.error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: vm.loadPlans,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (vm.plans.isEmpty) {
          return _EmptyPlans(
            onCreateTap: () async {
              final result =
                  await Navigator.pushNamed(context, '/workout-builder');
              if (result == true) vm.loadPlans();
            },
          );
        }

        return RefreshIndicator(
          onRefresh: vm.loadPlans,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: vm.plans.length,
            itemBuilder: (context, i) => _PlanCard(
              plan: vm.plans[i],
              onEdit: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/workout-builder',
                  arguments: {'planId': vm.plans[i].id},
                );
                if (result == true) vm.loadPlans();
              },
              onStart: () => Navigator.pushNamed(
                context,
                '/active-session',
                arguments: vm.plans[i],
              ),
              onDelete: () => _confirmDelete(context, vm, vm.plans[i]),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WorkoutHubViewModel vm,
    WorkoutPlanEntity plan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text('Delete "${plan.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await vm.deletePlan(plan.id);
    }
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // For plan cards, use repsWeight as default since we don't have
    // measurement details cached here (just the plan exercises).
    final estimate = DurationEstimator.formatEstimate(
      plan.exercises,
      {for (final e in plan.exercises) e.exerciseId: ExerciseMeasurement.repsWeight},
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.title,
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (plan.source == WorkoutSource.aiGenerated)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'AI',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onTertiaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: const Text('Delete'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                    child: const Icon(Icons.more_vert),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                children: [
                  _InfoChip(
                    icon: Icons.fitness_center,
                    label:
                        '${plan.exercises.length} exercise${plan.exercises.length == 1 ? '' : 's'}',
                  ),
                  if (estimate.isNotEmpty)
                    _InfoChip(icon: Icons.timer_outlined, label: estimate),
                  if (plan.scheduledDays.isNotEmpty)
                    _InfoChip(
                      icon: Icons.calendar_today,
                      label:
                          WeekHelper.formatScheduledDays(plan.scheduledDays),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Start'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(36),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _EmptyPlans extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyPlans({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 72, color: cs.outlineVariant),
            const SizedBox(height: 20),
            Text(
              'No workout plans yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first plan to start earning screen time.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Create Plan'),
            ),
          ],
        ),
      ),
    );
  }
}
