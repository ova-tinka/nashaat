import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../achievements/view-model/achievements-view-model.dart';
import '../../achievements/view/achievements-screen.dart';
import '../../../infra/repository-locator.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-nav-icon.dart';
import '../../../shared/design/atoms/app-status-pill.dart';
import '../../../shared/design/atoms/app-text.dart';
import '../../../shared/design/atoms/app-wasm-badge.dart';
import '../../../shared/design/molecules/app-banner.dart';
import '../../../shared/design/molecules/app-card.dart';
import '../../../shared/design/molecules/app-progress-bar.dart';
import '../../../shared/design/molecules/app-segmented-control.dart';
import '../../../shared/design/molecules/app-section-header.dart';
import '../../../shared/design/molecules/app-stat-tile.dart';
import '../../../shared/design/molecules/app-streak-loom.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/utils/week-helper.dart';
import '../view-model/dashboard-view-model.dart';

const _homeTabs = <AppSegmentOption<int>>[
  AppSegmentOption(value: 0, label: 'Dashboard'),
  AppSegmentOption(value: 1, label: 'Achievements'),
];

class DashboardScreen extends StatefulWidget {
  final bool isActive;
  final DashboardViewModel? viewModel;
  final AchievementsViewModel? achievementsViewModel;

  const DashboardScreen({
    super.key,
    this.isActive = true,
    this.viewModel,
    this.achievementsViewModel,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardViewModel _vm;
  late final AchievementsViewModel _achievementsVm;
  late final Listenable _listenable;
  late final bool _ownsDashboardViewModel;
  late final bool _ownsAchievementsViewModel;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    final userId =
        widget.viewModel == null || widget.achievementsViewModel == null
        ? Supabase.instance.client.auth.currentUser!.id
        : null;

    _ownsDashboardViewModel = widget.viewModel == null;
    _vm =
        widget.viewModel ??
        DashboardViewModel(
          userId: userId!,
          profileRepo: RepositoryLocator.instance.profile,
          pointAwardRepo: RepositoryLocator.instance.pointAward,
          logRepo: RepositoryLocator.instance.workoutLog,
          txnRepo: RepositoryLocator.instance.screenTimeTransaction,
        );

    _ownsAchievementsViewModel = widget.achievementsViewModel == null;
    _achievementsVm =
        widget.achievementsViewModel ??
        AchievementsViewModel(
          userId: userId!,
          achievementRepo: RepositoryLocator.instance.achievement,
        );

    _listenable = Listenable.merge([_vm, _achievementsVm]);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _refresh();
  }

  @override
  void dispose() {
    if (_ownsDashboardViewModel) _vm.dispose();
    if (_ownsAchievementsViewModel) _achievementsVm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return ListenableBuilder(
      listenable: _listenable,
      builder: (context, _) {
        if (_vm.isLoading && _vm.profile == null) {
          return Center(
            child: CircularProgressIndicator(color: palette.accent),
          );
        }

        return SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: palette.accent,
            backgroundColor: palette.card,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (_vm.error != null) ...[
                        AppBanner(
                          message: _vm.error!,
                          tone: AppStatusTone.attention,
                          icon: Icons.error_outline,
                          action: IconButton(
                            tooltip: 'Dismiss',
                            onPressed: _vm.clearError,
                            icon: Icon(
                              Icons.close,
                              size: 18,
                              color: palette.dangerText,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      _HomeHeader(vm: _vm),
                      const SizedBox(height: AppSpacing.lg),
                      if (_selectedTab == 0)
                        _HomeDashboard(
                          vm: _vm,
                          tabs: _homeTabs,
                          selectedTab: _selectedTab,
                          onTabChanged: (value) =>
                              setState(() => _selectedTab = value),
                        )
                      else ...[
                        _HomeTabs(
                          selected: _selectedTab,
                          onChanged: (value) =>
                              setState(() => _selectedTab = value),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AchievementsScreen(viewModel: _achievementsVm),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _refresh() async {
    await Future.wait([_vm.load(), _achievementsVm.load()]);
  }
}

class _HomeHeader extends StatelessWidget {
  final DashboardViewModel vm;

  const _HomeHeader({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppWasmBadge(label: _initial(vm.displayName), size: 52),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText.section('WELCOME BACK,'),
              Text(
                vm.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.nashaatPalette.reward.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 12, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.card_membership_outlined,
                  size: 19,
                  color: context.nashaatPalette.rewardText,
                ),
                const SizedBox(width: 6),
                Text(
                  '${vm.streakCount}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.nashaatPalette.rewardText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  final DashboardViewModel vm;
  final List<AppSegmentOption<int>> tabs;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  const _HomeDashboard({
    required this.vm,
    required this.tabs,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PointsSummary(vm: vm),
        const SizedBox(height: AppSpacing.md),
        _StreakCard(vm: vm),
        const SizedBox(height: AppSpacing.lg),
        AppSegmentedControl<int>(
          options: tabs,
          selected: selectedTab,
          onChanged: onTabChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppText.title('Recent points'),
        const SizedBox(height: AppSpacing.md),
        _RecentPointsCard(vm: vm),
        const SizedBox(height: AppSpacing.lg),
        _BalanceHero(vm: vm),
        const SizedBox(height: AppSpacing.md),
        _WeeklyProgressCard(vm: vm),
        AppSectionHeader('This week'),
        _WeeklyMetrics(vm: vm),
        const SizedBox(height: AppSpacing.md),
        _ActivityChart(vm: vm),
      ],
    );
  }
}

class _BalanceHero extends StatelessWidget {
  final DashboardViewModel vm;

  const _BalanceHero({required this.vm});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final balance = vm.screenTimeBalanceMinutes;
    final hasBalance = balance > 0;
    return AppCard(
      key: const ValueKey('home-balance-card'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText.section('SCREEN-TIME BALANCE'),
              AppStatusPill(
                label: hasBalance ? 'Available' : 'Earn more',
                tone: hasBalance ? AppStatusTone.accent : AppStatusTone.locked,
                showDot: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _formatMinutes(balance),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: hasBalance ? palette.accentText : palette.lockedText,
              fontSize: 38,
            ),
          ),
          AppText.bodyMuted(
            hasBalance
                ? 'available to use'
                : 'Finish a workout to unlock more time',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.primary(
            key: const ValueKey('home-start-workout'),
            'Start workout',
            icon: Icons.play_arrow_rounded,
            onPressed: () =>
                Navigator.of(context).pushNamed('/workout-builder'),
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}

class _WeeklyProgressCard extends StatelessWidget {
  final DashboardViewModel vm;

  const _WeeklyProgressCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final status = vm.goalStatus;
    final tone = switch (status) {
      'Strong' => AppStatusTone.accent,
      'Stable' => AppStatusTone.calm,
      _ => AppStatusTone.reward,
    };
    final activeColor = switch (status) {
      'Strong' => palette.accent,
      'Stable' => palette.calm,
      _ => palette.reward,
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly goal',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              AppStatusPill(
                label: status,
                tone: tone,
                dashed: status == 'Needs Attention',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppProgressBar(
            value: vm.weeklyProgress,
            activeColor: activeColor,
            height: 8,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppText.bodyMuted(
            '${vm.weeklyMinutesTrained} / ${vm.weeklyTargetMinutes} minutes trained',
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final DashboardViewModel vm;

  const _StreakCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final streak = vm.streakCount;
    final completedBands = _completedStreakBands(streak);
    final progress = _currentBandProgress(streak, completedBands);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _StreakMetric(
                  label: 'CURRENT STREAK',
                  value: '$streak days',
                  accent: true,
                ),
              ),
              Expanded(
                child: _StreakMetric(
                  label: 'LONGEST STREAK',
                  value: '${vm.longestStreak} days',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText.section('YOUR LOOM'),
              AppText.bodyMuted('8 milestones'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppStreakLoom(
            completedBands: completedBands,
            currentProgress: progress,
            bandHeight: 28,
            gap: 7,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: _streakMilestones
                .map(
                  (milestone) => Expanded(
                    child: Text(
                      '$milestone',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: streak >= milestone
                            ? context.nashaatPalette.rewardText
                            : context.nashaatPalette.textMuted,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppText.bodyMuted(_nextBandLabel(streak, completedBands)),
        ],
      ),
    );
  }
}

class _StreakMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;

  const _StreakMetric({
    required this.label,
    required this.value,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.bodyMuted(label),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: accent ? palette.rewardText : palette.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _PointsSummary extends StatelessWidget {
  final DashboardViewModel vm;

  const _PointsSummary({required this.vm});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return AppCard.standard(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [palette.textPrimary, palette.textSecondary],
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.textPrimary.withValues(alpha: 0.12),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const SizedBox.shrink(),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.section('TOTAL POINTS'),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _formatPoints(vm.totalPoints),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 48,
                    height: 0.95,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _HomeTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AppSegmentedControl<int>(
      options: _homeTabs,
      selected: selected,
      onChanged: onChanged,
    );
  }
}

class _RecentPointsCard extends StatelessWidget {
  final DashboardViewModel vm;

  const _RecentPointsCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final awards = vm.recentPointAwards;
    if (awards.isEmpty) {
      return AppCard.flat(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: AppText.bodyMuted(
          'Finish a workout of at least 5 minutes to start earning points.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(awards.length, (index) {
          final award = awards[index];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: AppNavIcon(
                        glyph: AppNavGlyph.crossedOars,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        award.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '+${award.points}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: palette.rewardText,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < awards.length - 1)
                Divider(height: 1, color: palette.border),
            ],
          );
        }),
      ),
    );
  }
}

class _WeeklyMetrics extends StatelessWidget {
  final DashboardViewModel vm;

  const _WeeklyMetrics({required this.vm});

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final metrics = <_HomeMetric>[
      if (isIOS)
        _HomeMetric(
          _formatMinutes(vm.weeklyEarnedMinutes),
          'Earned',
          Icons.timer_outlined,
        ),
      if (isIOS)
        _HomeMetric(
          _formatMinutes(vm.weeklySpentMinutes),
          'Spent',
          Icons.phone_android,
        ),
      if (isIOS)
        _HomeMetric(
          _formatMinutes(vm.screenTimeBalanceMinutes),
          'Balance',
          Icons.account_balance_wallet_outlined,
        ),
      _HomeMetric(
        '${vm.weeklySessionsCompleted}',
        'Sessions',
        Icons.fitness_center,
      ),
      _HomeMetric(
        _formatMinutes(vm.weeklyMinutesTrained),
        'Trained',
        Icons.timer,
      ),
      _HomeMetric(
        _formatMinutes(vm.weeklyTargetMinutes),
        'Target',
        Icons.flag_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = AppSpacing.sm;
        final width = (constraints.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: AppStatTile(
                    value: metric.value,
                    label: metric.label,
                    icon: metric.icon,
                    accentColor: metric.label == 'Earned'
                        ? context.nashaatPalette.accentText
                        : null,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _HomeMetric {
  final String value;
  final String label;
  final IconData icon;

  const _HomeMetric(this.value, this.label, this.icon);
}

class _ActivityChart extends StatelessWidget {
  final DashboardViewModel vm;

  const _ActivityChart({required this.vm});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final textTheme = Theme.of(context).textTheme;
    final spots = vm.weeklyActivitySpots;
    final maxY = spots.reduce((a, b) => a > b ? a : b).clamp(1.0, 999.0);
    final weekDays = WeekHelper.currentWeekDays();
    final lineSpots = List.generate(
      spots.length,
      (index) => FlSpot(index.toDouble(), spots[index]),
    );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.base,
        AppSpacing.base,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Weekly activity', style: textTheme.titleSmall),
              AppText.bodyMuted('Sessions per day'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 128,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxY + 1,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: palette.border, strokeWidth: 1),
                  drawVerticalLine: false,
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= weekDays.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            WeekHelper.shortDayLabel(weekDays[index].weekday),
                            style: textTheme.labelSmall?.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: lineSpots,
                    isCurved: false,
                    color: palette.accent,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 3.5,
                            color: palette.reward,
                            strokeWidth: 1.5,
                            strokeColor: palette.textPrimary,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: palette.accent.withValues(alpha: 0.10),
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

const _streakMilestones = <int>[3, 7, 14, 30, 60, 100, 180, 365];

int _completedStreakBands(int streak) {
  return _streakMilestones.where((milestone) => streak >= milestone).length;
}

double _currentBandProgress(int streak, int completedBands) {
  if (completedBands >= _streakMilestones.length) return 1;
  final previous = completedBands == 0
      ? 0
      : _streakMilestones[completedBands - 1];
  final next = _streakMilestones[completedBands];
  return ((streak - previous) / (next - previous)).clamp(0.0, 1.0);
}

String _nextBandLabel(int streak, int completedBands) {
  if (completedBands >= _streakMilestones.length) {
    return 'All eight bands are woven.';
  }
  final next = _streakMilestones[completedBands];
  final remaining = next - streak;
  if (streak == 0) return 'First band at a $next-day streak.';
  return 'Next band at $next days · $remaining to go.';
}

String _formatMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}

String _formatPoints(int points) {
  final value = points.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    if (i > 0 && (value.length - i) % 3 == 0) buffer.write(',');
    buffer.write(value[i]);
  }
  return buffer.toString();
}

String _initial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'N';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}
