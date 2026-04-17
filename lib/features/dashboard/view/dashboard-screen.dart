import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../infra/repository-locator.dart';
import '../../../shared/design/molecules/app-card.dart';
import '../../../shared/design/molecules/app-section-header.dart';
import '../../../shared/design/molecules/app-stat-tile.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
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
          color: AppColors.ink,
          backgroundColor: AppColors.paper,
          onRefresh: _vm.load,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text('PROGRESS', style: AppTypography.sectionHeader.copyWith(fontSize: 13, letterSpacing: 2)),
                centerTitle: false,
                pinned: true,
                backgroundColor: AppColors.paper,
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0,
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(1),
                  child: Divider(height: 1, thickness: 1, color: AppColors.paperBorder),
                ),
              ),
              if (_vm.error != null)
                SliverToBoxAdapter(
                  child: _ErrorBanner(message: _vm.error!, onDismiss: _vm.clearError),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xl
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _ProfileHeader(vm: _vm),
                    const SizedBox(height: AppSpacing.lg),
                    AppSectionHeader('This Week'),
                    const SizedBox(height: AppSpacing.sm),
                    _WeeklyMetrics(vm: _vm),
                    const SizedBox(height: AppSpacing.base),
                    _ActivityChart(vm: _vm),
                    const SizedBox(height: AppSpacing.base),
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
    final streak = vm.streakCount;
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          color: AppColors.ink,
          alignment: Alignment.center,
          child: Text(
            vm.displayName.substring(0, 1).toUpperCase(),
            style: AppTypography.title.copyWith(color: AppColors.paper),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back,', style: AppTypography.labelMuted),
              Text(vm.displayName, style: AppTypography.title),
            ],
          ),
        ),
        if (streak > 0) _StreakBadge(streak: streak),
      ],
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: AppColors.signal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, size: 14, color: AppColors.ink),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: AppTypography.monoStrong.copyWith(fontSize: 14),
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
      children: [
        Row(
          children: [
            Expanded(child: AppStatTile(value: _fmt(vm.weeklyEarnedMinutes), label: 'Earned', icon: Icons.timer_outlined)),
            const SizedBox(width: 8),
            Expanded(child: AppStatTile(value: _fmt(vm.weeklySpentMinutes), label: 'Spent', icon: Icons.phone_android)),
            const SizedBox(width: 8),
            Expanded(child: AppStatTile(value: _fmt(vm.screenTimeBalanceMinutes), label: 'Balance', icon: Icons.account_balance_wallet_outlined)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: AppStatTile(value: '${vm.weeklySessionsCompleted}', label: 'Sessions', icon: Icons.fitness_center)),
            const SizedBox(width: 8),
            Expanded(child: AppStatTile(value: _fmt(vm.weeklyMinutesTrained), label: 'Trained', icon: Icons.timer)),
            const SizedBox(width: 8),
            Expanded(child: AppStatTile(value: _fmt(vm.weeklyTargetMinutes), label: 'Target', icon: Icons.flag_outlined, accentColor: AppColors.inkMuted)),
          ],
        ),
      ],
    );
  }

  String _fmt(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

// ── Activity chart ────────────────────────────────────────────────────────────

class _ActivityChart extends StatelessWidget {
  final DashboardViewModel vm;
  const _ActivityChart({required this.vm});

  @override
  Widget build(BuildContext context) {
    final spots = vm.weeklyActivitySpots;
    final maxY = spots.reduce((a, b) => a > b ? a : b).clamp(1.0, 999.0);
    final weekDays = WeekHelper.currentWeekDays();
    final lineSpots = List.generate(spots.length, (i) => FlSpot(i.toDouble(), spots[i]));

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Activity', style: AppTypography.heading.copyWith(fontSize: 15)),
          const SizedBox(height: 2),
          Text('Sessions per day this week', style: AppTypography.labelMuted),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                minX: 0, maxX: 6, minY: 0, maxY: maxY + 1,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (v) => const FlLine(
                    color: AppColors.paperBorder,
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
                        if (idx < 0 || idx >= weekDays.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            WeekHelper.shortDayLabel(weekDays[idx].weekday),
                            style: AppTypography.mono.copyWith(fontSize: 10, color: AppColors.inkMuted),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: lineSpots,
                    isCurved: false,
                    color: AppColors.ink,
                    barWidth: 2,
                    isStrokeCapRound: false,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: AppColors.acid,
                        strokeWidth: 1,
                        strokeColor: AppColors.ink,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.paperAlt,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    final status = vm.goalStatus;
    final progress = vm.weeklyProgress;
    final statusBg = switch (status) {
      'Strong' => AppColors.acid,
      'Stable' => AppColors.signal,
      _ => AppColors.errorMuted,
    };
    final statusFg = switch (status) {
      'Strong' => AppColors.ink,
      'Stable' => AppColors.ink,
      _ => AppColors.error,
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Weekly Goal', style: AppTypography.heading.copyWith(fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: statusBg,
                child: Text(status.toUpperCase(), style: AppTypography.sectionHeader.copyWith(color: statusFg, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.paperBorder,
            color: AppColors.ink,
            borderRadius: BorderRadius.zero,
          ),
          const SizedBox(height: 8),
          Text(
            '${vm.weeklyMinutesTrained} / ${vm.weeklyTargetMinutes} minutes trained',
            style: AppTypography.labelMuted,
          ),
        ],
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
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorMuted,
        border: Border.all(color: AppColors.error, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: AppTypography.body.copyWith(color: AppColors.error))),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, color: AppColors.error, size: 16),
          ),
        ],
      ),
    );
  }
}
