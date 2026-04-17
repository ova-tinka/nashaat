import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../infra/repository-locator.dart';
import '../../../shared/utils/week-helper.dart';
import '../view-model/dashboard-view-model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardViewModel _vm;

  @override
  void initState() {
    super.initState();
    final userId = Supabase.instance.client.auth.currentUser!.id;
    _vm = DashboardViewModel(
      userId: userId,
      profileRepo: RepositoryLocator.instance.profile,
      logRepo: RepositoryLocator.instance.workoutLog,
      txnRepo: RepositoryLocator.instance.screenTimeTransaction,
    );
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.isLoading && _vm.profile == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: _vm.load,
          child: CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: const Text('Progress'),
                centerTitle: false,
                floating: true,
                snap: true,
              ),
              if (_vm.error != null)
                SliverToBoxAdapter(
                  child: _ErrorBanner(
                    message: _vm.error!,
                    onDismiss: _vm.clearError,
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _ProfileHeader(vm: _vm),
                    const SizedBox(height: 20),
                    _WeeklyMetrics(vm: _vm),
                    const SizedBox(height: 20),
                    _ActivityChart(vm: _vm),
                    const SizedBox(height: 20),
                    _GoalCard(vm: _vm),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final DashboardViewModel vm;
  const _ProfileHeader({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final streak = vm.streakCount;

    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: cs.primaryContainer,
          child: Text(
            vm.displayName.substring(0, 1).toUpperCase(),
            style: tt.headlineSmall?.copyWith(color: cs.onPrimaryContainer),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                vm.displayName,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        if (streak > 0)
          _StreakBadge(streak: streak),
      ],
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, size: 16),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ── Weekly metrics ────────────────────────────────────────────────────────────

class _WeeklyMetrics extends StatelessWidget {
  final DashboardViewModel vm;
  const _WeeklyMetrics({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This Week',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Earned',
                value: _formatMinutes(vm.weeklyEarnedMinutes),
                icon: Icons.timer_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: 'Spent',
                value: _formatMinutes(vm.weeklySpentMinutes),
                icon: Icons.phone_android,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: 'Balance',
                value: _formatMinutes(vm.screenTimeBalanceMinutes),
                icon: Icons.account_balance_wallet_outlined,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Sessions',
                value: '${vm.weeklySessionsCompleted}',
                icon: Icons.fitness_center,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: 'Trained',
                value: _formatMinutes(vm.weeklyMinutesTrained),
                icon: Icons.timer,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: 'Target',
                value: _formatMinutes(vm.weeklyTargetMinutes),
                icon: Icons.flag_outlined,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            Text(
              label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Activity chart ────────────────────────────────────────────────────────────

class _ActivityChart extends StatelessWidget {
  final DashboardViewModel vm;
  const _ActivityChart({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final spots = vm.weeklyActivitySpots;
    final maxY = spots.reduce((a, b) => a > b ? a : b).clamp(1.0, 999.0);
    final weekDays = WeekHelper.currentWeekDays();

    final lineSpots = List.generate(
      spots.length,
      (i) => FlSpot(i.toDouble(), spots[i]),
    );

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Activity',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Sessions per day this week',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 6,
                  minY: 0,
                  maxY: maxY + 1,
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: cs.outlineVariant.withOpacity(0.3),
                      strokeWidth: 1,
                    ),
                    drawVerticalLine: false,
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= weekDays.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              WeekHelper.shortDayLabel(weekDays[idx].weekday),
                              style: tt.labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: lineSpots,
                      isCurved: true,
                      color: cs.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: cs.primary,
                          strokeWidth: 0,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: cs.primary.withOpacity(0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Goal card ─────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final DashboardViewModel vm;
  const _GoalCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final status = vm.goalStatus;
    final progress = vm.weeklyProgress;
    final statusColor = switch (status) {
      'Strong' => Colors.green,
      'Stable' => cs.primary,
      _ => cs.error,
    };

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly Goal',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: tt.labelMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${vm.weeklyMinutesTrained} / ${vm.weeklyTargetMinutes} minutes trained',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }
}
