import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../infra/blocking/blocking-platform-service.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-chip.dart';
import '../../../shared/design/atoms/app-sadu-band.dart';
import '../../../shared/design/atoms/app-status-pill.dart';
import '../../../shared/design/atoms/app-text.dart';
import '../../../shared/design/molecules/app-card.dart';
import '../../../shared/design/molecules/app-dotted-slider.dart';
import '../../../shared/design/organisms/app-step-scaffold.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/utils/screen-time-economy.dart';
import '../coordinator/onboarding-coordinator.dart';
import '../view-model/onboarding-view-model.dart';

class OnboardingScreen extends StatefulWidget {
  final OnboardingViewModel vm;
  final OnboardingCoordinator coordinator;

  const OnboardingScreen({
    super.key,
    required this.vm,
    required this.coordinator,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  void initState() {
    super.initState();
    widget.vm.addListener(_onVmChanged);
  }

  @override
  void dispose() {
    widget.vm.removeListener(_onVmChanged);
    super.dispose();
  }

  void _onVmChanged() {
    if (widget.vm.isDone) {
      widget.coordinator.done();
      return;
    }
    if (widget.vm.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.vm.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.vm,
      builder: (context, _) {
        return PopScope(
          canPop: widget.vm.step == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) widget.vm.goBack();
          },
          child: _buildStep(context),
        );
      },
    );
  }

  Widget _buildStep(BuildContext context) {
    final vm = widget.vm;
    final l10n = AppLocalizations.of(context)!;
    switch (vm.step) {
      case 0:
        return AppStepScaffold(
          totalSteps: vm.totalSteps,
          currentStep: 0,
          nextLabel: l10n.onboardingLetsGo,
          progressLabel: l10n.onboardingStep(1, vm.totalSteps),
          onBack: null,
          onNext: vm.goNext,
          body: _WelcomeStep(
            initial: vm.username,
            onChanged: vm.setUsername,
            supportsScreenTime: vm.supportsScreenTime,
          ),
        );
      case 1:
        return AppStepScaffold(
          totalSteps: vm.totalSteps,
          currentStep: 1,
          progressLabel: l10n.onboardingStep(2, vm.totalSteps),
          backLabel: l10n.back,
          onBack: vm.goBack,
          onNext: vm.goNext,
          body: _DaysPerWeekStep(
            value: vm.daysPerWeek,
            onChanged: vm.setDaysPerWeek,
          ),
        );
      case 2:
        return AppStepScaffold(
          totalSteps: vm.totalSteps,
          currentStep: 2,
          nextLabel: vm.supportsScreenTime
              ? l10n.next
              : l10n.onboardingFinishSetup,
          progressLabel: l10n.onboardingStep(3, vm.totalSteps),
          backLabel: l10n.back,
          onBack: vm.goBack,
          onNext: vm.supportsScreenTime ? vm.goNext : () => vm.finish(),
          body: _WorkoutDurationStep(
            value: vm.workoutDurationMinutes,
            daysPerWeek: vm.daysPerWeek,
            onChanged: vm.setWorkoutDurationMinutes,
          ),
        );
      case 3:
        return AppStepScaffold(
          totalSteps: vm.totalSteps,
          currentStep: 3,
          progressLabel: l10n.onboardingStep(4, vm.totalSteps),
          backLabel: l10n.back,
          onBack: vm.goBack,
          onNext: vm.goNext,
          body: _DailyPhoneHoursStep(
            value: vm.dailyPhoneHours,
            onChanged: vm.setDailyPhoneHours,
          ),
        );
      case 4:
        return AppStepScaffold(
          totalSteps: vm.totalSteps,
          currentStep: 4,
          progressLabel: l10n.onboardingStep(5, vm.totalSteps),
          backLabel: l10n.back,
          onBack: vm.goBack,
          onNext: vm.goNext,
          body: _RewardPreviewStep(
            name: vm.username,
            daysPerWeek: vm.daysPerWeek,
            workoutDurationMinutes: vm.workoutDurationMinutes,
            dailyPhoneHours: vm.dailyPhoneHours,
            weeklySmallSessions: vm.weeklySmallSessions,
            weeklyBigSessions: vm.weeklyBigSessions,
            onSmallChanged: vm.setWeeklySmallSessions,
            onBigChanged: vm.setWeeklyBigSessions,
          ),
        );
      case 5:
        return _BlockingStep(
          totalSteps: vm.totalSteps,
          onBack: vm.goBack,
          isSaving: vm.isSaving,
          onContinue: (packages) => vm.finish(packages: packages),
          onSkip: vm.finish,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Step 0 — Welcome / username ───────────────────────────────────────────────

class _WelcomeStep extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  final bool supportsScreenTime;

  const _WelcomeStep({
    required this.initial,
    required this.onChanged,
    required this.supportsScreenTime,
  });

  @override
  State<_WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<_WelcomeStep> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSaduBand(motif: AppSaduMotif.chevrons, height: 64),
          const SizedBox(height: AppSpacing.lg),
          AppText.section('WELCOME TO'),
          AppText.hero('Nashaat'),
          const SizedBox(height: AppSpacing.md),
          AppText.bodyMuted(
            widget.supportsScreenTime
                ? l10n.onboardingWelcomeBodyScreenTime
                : l10n.onboardingWelcomeBodyWorkout,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppText.body(l10n.onboardingNamePrompt),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              hintText: l10n.onboardingUsernameHint,
              helperText: 'Optional · letters a–z, numbers and _ only',
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
            ],
            textCapitalization: TextCapitalization.none,
            onChanged: widget.onChanged,
          ),
        ],
      ),
    );
  }
}

// ── Step 1 — Days per week ────────────────────────────────────────────────────

class _DaysPerWeekStep extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _DaysPerWeekStep({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.section('YOUR WEEK'),
          const SizedBox(height: AppSpacing.sm),
          AppText.hero(l10n.onboardingDaysTitle),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: List.generate(7, (index) {
              final day = index + 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: index == 6 ? 0 : AppSpacing.xs,
                  ),
                  child: _DayNumberChip(
                    value: day,
                    selected: day <= value,
                    onTap: () => onChanged(day),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard.standard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText.title(l10n.onboardingDaysPerWeek(value)),
                    ),
                    AppStatusPill(label: 'Solid', tone: AppStatusTone.calm),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                      .asMap()
                      .entries
                      .map(
                        (entry) => AppDayChip(
                          label: entry.value,
                          selected: entry.key < value,
                          onTap: () => onChanged(entry.key + 1),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppText.bodyMuted('You can change this any time in Profile.'),
        ],
      ),
    );
  }
}

class _DayNumberChip extends StatelessWidget {
  final int value;
  final bool selected;
  final VoidCallback onTap;

  const _DayNumberChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.calm : Colors.transparent,
          border: Border.all(
            color: selected ? palette.calm : palette.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$value',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: selected ? palette.calmInk : palette.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Step 2 — Workout duration ─────────────────────────────────────────────────

class _WorkoutDurationStep extends StatelessWidget {
  final int value;
  final int daysPerWeek;
  final ValueChanged<int> onChanged;
  const _WorkoutDurationStep({
    required this.value,
    required this.daysPerWeek,
    required this.onChanged,
  });

  static const _durations = [15, 30, 45, 60, 90];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.section('EACH WORKOUT'),
          const SizedBox(height: AppSpacing.sm),
          AppText.hero(l10n.onboardingDurationTitle),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: _durations.map((d) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: d == _durations.last ? 0 : AppSpacing.xs,
                  ),
                  child: _DurationOption(
                    label: l10n.onboardingDurationOption(d),
                    selected: d == value,
                    onTap: () => onChanged(d),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard.standard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.section('WEEKLY TRAINING TARGET'),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppText.hero('${daysPerWeek * value}'),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: AppText.bodyMuted(
                          'min a week',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                AppText.bodyMuted('$daysPerWeek days × $value min'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DurationOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.calm : Colors.transparent,
          border: Border.all(
            color: selected ? palette.calm : palette.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: selected ? palette.calmInk : palette.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Step 3 — Daily phone hours ────────────────────────────────────────────────

class _DailyPhoneHoursStep extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _DailyPhoneHoursStep({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.section('DAILY PHONE USAGE'),
          const SizedBox(height: AppSpacing.sm),
          AppText.hero(l10n.onboardingPhoneTitle),
          const SizedBox(height: AppSpacing.sm),
          AppText.bodyMuted(l10n.onboardingPhoneBody),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: AppText.hero(
              l10n.onboardingPhoneHours(value),
              color: context.nashaatPalette.accentText,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          AppDottedSlider(
            values: List<int>.generate(16, (index) => index + 1),
            value: value,
            onChanged: onChanged,
            useAccent: true,
            semanticLabel: l10n.onboardingPhoneTitle,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText.mono(l10n.onboardingPhoneMinimum),
              AppText.mono(l10n.onboardingPhoneMaximum),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppText.bodyMuted(
            'Not sure? Open Settings → Screen Time on your iPhone.',
          ),
        ],
      ),
    );
  }
}

// ── Step 4 — Reward preview + session setup ───────────────────────────────────

class _RewardPreviewStep extends StatelessWidget {
  final String name;
  final int daysPerWeek;
  final int workoutDurationMinutes;
  final int dailyPhoneHours;
  final int weeklySmallSessions;
  final int weeklyBigSessions;
  final ValueChanged<int> onSmallChanged;
  final ValueChanged<int> onBigChanged;

  const _RewardPreviewStep({
    required this.name,
    required this.daysPerWeek,
    required this.workoutDurationMinutes,
    required this.dailyPhoneHours,
    required this.weeklySmallSessions,
    required this.weeklyBigSessions,
    required this.onSmallChanged,
    required this.onBigChanged,
  });

  String _fmt(int m) {
    final h = m ~/ 60;
    final min = m % 60;
    if (h > 0 && min == 0) return '${h}h';
    return h > 0 ? '${h}h ${min}m' : '${min}m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rewards = ScreenTimeEconomy.calculateRaw(
      dailyPhoneHours: dailyPhoneHours,
      weeklySmallSessions: weeklySmallSessions,
      weeklyBigSessions: weeklyBigSessions,
    );
    final weeklyTargetMinutes = daysPerWeek * workoutDurationMinutes;

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.section('YOUR REWARD PREVIEW'),
          const SizedBox(height: AppSpacing.sm),
          AppText.hero(
            "Here's your week,\n${name.trim().isEmpty ? 'there' : name}",
          ),
          const SizedBox(height: AppSpacing.md),
          _RewardLegend(),
          const SizedBox(height: AppSpacing.md),
          AppCard.standard(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RewardRow(
                  l10n.onboardingWeeklyTarget,
                  _fmt(weeklyTargetMinutes),
                ),
                const SizedBox(height: 8),
                _RewardRow(l10n.onboardingFreeTime, _fmt(rewards.freeMinutes)),
                const SizedBox(height: 8),
                _RewardRow(
                  l10n.onboardingSmallSessionReward,
                  _fmt(rewards.smallRewardMinutes),
                  valueColor: context.nashaatPalette.accentText,
                ),
                const SizedBox(height: 8),
                _RewardRow(
                  l10n.onboardingBigSessionReward,
                  _fmt(rewards.bigRewardMinutes),
                  valueColor: context.nashaatPalette.accentText,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _SessionCountPill(
                  value: weeklySmallSessions,
                  label: l10n.onboardingSmallSessionShort,
                  onChanged: onSmallChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SessionCountPill(
                  value: weeklyBigSessions,
                  label: l10n.onboardingBigSessionShort,
                  onChanged: onBigChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppText.bodyMuted('each week'),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _RewardRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: AppText.body(label)),
        AppText.monoStrong(value, color: valueColor),
      ],
    );
  }
}

class _SessionCountPill extends StatelessWidget {
  final int value;
  final String label;
  final ValueChanged<int> onChanged;

  const _SessionCountPill({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Semantics(
      button: true,
      label: label,
      value: '$value each week',
      onIncrease: () => onChanged(value + 1),
      onDecrease: value > 0 ? () => onChanged(value - 1) : null,
      child: GestureDetector(
        onTap: () => onChanged(value + 1),
        onLongPress: value > 0 ? () => onChanged(value - 1) : null,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: AppText.body('$value × $label', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _RewardLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    final colors = [
      palette.calm,
      palette.accent.withValues(alpha: 0.65),
      palette.accent,
    ];
    return Column(
      children: [
        Row(
          children: List.generate(
            6,
            (index) => Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  end: index == 5 ? 0 : AppSpacing.xs,
                ),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _LegendItem(color: palette.calm, label: 'Free'),
            _LegendItem(
              color: palette.accent.withValues(alpha: 0.65),
              label: 'Small',
            ),
            _LegendItem(color: palette.accent, label: 'Big'),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const SizedBox.square(dimension: 10),
          ),
          const SizedBox(width: AppSpacing.xs),
          AppText.bodyMuted(label),
        ],
      ),
    );
  }
}

// ── Step 5 — Blocking preferences ────────────────────────────────────────────

class _BlockingStep extends StatefulWidget {
  final int totalSteps;
  final VoidCallback onBack;
  final bool isSaving;
  final Future<void> Function(List<String>) onContinue;
  final Future<void> Function() onSkip;

  const _BlockingStep({
    required this.totalSteps,
    required this.onBack,
    required this.isSaving,
    required this.onContinue,
    required this.onSkip,
  });

  @override
  State<_BlockingStep> createState() => _BlockingStepState();
}

class _BlockingStepState extends State<_BlockingStep> {
  final _platform = BlockingPlatformService();
  List<InstalledApp> _installedApps = [];
  final Set<String> _selected = {};
  bool _loadingApps = false;
  bool _iosPickerDone = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() => _loadingApps = true);
    try {
      final apps = await _platform.getInstalledApps();
      if (mounted) setState(() => _installedApps = apps);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingApps = false);
    }
  }

  Future<void> _openIosPicker() async {
    try {
      final count = await _platform.presentIosPicker();
      if (count > 0 && mounted) setState(() => _iosPickerDone = true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppStepScaffold(
      totalSteps: widget.totalSteps,
      currentStep: 5,
      nextLabel: l10n.onboardingFinishSetup,
      progressLabel: l10n.onboardingStep(6, widget.totalSteps),
      backLabel: l10n.back,
      isLoading: widget.isSaving,
      onBack: widget.onBack,
      onNext: () => widget.onContinue(_selected.toList()),
      skipLabel: l10n.onboardingSkipForNow,
      onSkip: widget.isSaving ? null : widget.onSkip,
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.base,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText.section(l10n.onboardingBlockingKicker),
            const SizedBox(height: AppSpacing.sm),
            AppText.hero(l10n.onboardingBlockingTitle),
            const SizedBox(height: AppSpacing.md),
            AppText.bodyMuted(l10n.onboardingBlockingBody),
            const SizedBox(height: AppSpacing.xl),
            if (Platform.isIOS) ...[
              _IosPickerSection(iosDone: _iosPickerDone, onTap: _openIosPicker),
            ] else ...[
              if (_loadingApps)
                Center(
                  child: CircularProgressIndicator(
                    color: context.nashaatPalette.accent,
                  ),
                )
              else if (_installedApps.isEmpty)
                AppText.bodyMuted(l10n.onboardingNoApps)
              else
                ..._installedApps.map((app) {
                  final checked = _selected.contains(app.packageId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      child: CheckboxListTile(
                        value: checked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selected.add(app.packageId);
                            } else {
                              _selected.remove(app.packageId);
                            }
                          });
                        },
                        title: AppText.body(app.name),
                        subtitle: AppText.mono(app.packageId),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}

class _IosPickerSection extends StatelessWidget {
  final bool iosDone;
  final VoidCallback onTap;
  const _IosPickerSection({required this.iosDone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BlockingAppGrid(),
        const SizedBox(height: AppSpacing.lg),
        AppText.bodyMuted(l10n.onboardingBlockingHint),
        const SizedBox(height: AppSpacing.lg),
        AppButton.primary(
          l10n.onboardingChooseViaScreenTime,
          onPressed: onTap,
          width: double.infinity,
        ),
        if (iosDone) ...[
          const SizedBox(height: AppSpacing.md),
          AppStatusPill(
            label: l10n.onboardingAppsSelected,
            tone: AppStatusTone.accent,
            showDot: true,
          ),
        ],
      ],
    );
  }
}

class _BlockingAppGrid extends StatelessWidget {
  const _BlockingAppGrid();

  static const _swatches = [
    Color(0xff6288a8),
    Color(0xffc37a5c),
    Color(0xff72a16e),
    Color(0xff976ab1),
    Color(0xffd4a345),
    Color(0xff4d9590),
    Color(0xffbd5b7d),
    Color(0xff7e838a),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var index = 0; index < _swatches.length; index++)
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _swatches[index],
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
      ],
    );
  }
}
