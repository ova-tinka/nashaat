import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../infra/blocking/blocking-platform-service.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-chip.dart';
import '../../../shared/design/atoms/app-status-pill.dart';
import '../../../shared/design/atoms/app-text.dart';
import '../../../shared/design/molecules/app-card.dart';
import '../../../shared/design/molecules/app-counter.dart';
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
          AppText.title(l10n.onboardingWelcomeTitle),
          const SizedBox(height: AppSpacing.md),
          AppText.bodyMuted(
            widget.supportsScreenTime
                ? l10n.onboardingWelcomeBodyScreenTime
                : l10n.onboardingWelcomeBodyWorkout,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppText.heading(l10n.onboardingNamePrompt),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              labelText: l10n.onboardingUsernameOptional,
              hintText: l10n.onboardingUsernameHint,
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
          AppText.title(l10n.onboardingDaysTitle),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: AppText.display(
              '$value',
              color: context.nashaatPalette.calmText,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(child: AppText.bodyMuted(l10n.onboardingDaysPerWeek(value))),
          const SizedBox(height: AppSpacing.lg),
          AppDottedSlider(
            values: List<int>.generate(7, (index) => index + 1),
            value: value,
            onChanged: onChanged,
            semanticLabel: l10n.onboardingDaysTitle,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [AppText.mono('1'), AppText.mono('7')],
          ),
        ],
      ),
    );
  }
}

// ── Step 2 — Workout duration ─────────────────────────────────────────────────

class _WorkoutDurationStep extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _WorkoutDurationStep({required this.value, required this.onChanged});

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
          AppText.title(l10n.onboardingDurationTitle),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _durations.map((d) {
              return AppSelectChip(
                label: l10n.onboardingDurationOption(d),
                selected: d == value,
                onTap: () => onChanged(d),
                tone: AppStatusTone.calm,
              );
            }).toList(),
          ),
        ],
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
          AppText.title(l10n.onboardingPhoneTitle),
          const SizedBox(height: AppSpacing.sm),
          AppText.bodyMuted(l10n.onboardingPhoneBody),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: AppText.display(
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
        ],
      ),
    );
  }
}

// ── Step 4 — Reward preview + session setup ───────────────────────────────────

class _RewardPreviewStep extends StatelessWidget {
  final int daysPerWeek;
  final int workoutDurationMinutes;
  final int dailyPhoneHours;
  final int weeklySmallSessions;
  final int weeklyBigSessions;
  final ValueChanged<int> onSmallChanged;
  final ValueChanged<int> onBigChanged;

  const _RewardPreviewStep({
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
          AppText.title(l10n.onboardingRewardTitle),
          const SizedBox(height: AppSpacing.lg),
          AppCard.reward(
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
                ),
                const SizedBox(height: 8),
                _RewardRow(
                  l10n.onboardingBigSessionReward,
                  _fmt(rewards.bigRewardMinutes),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          AppText.heading(l10n.onboardingWeeklySessionSplit),
          const SizedBox(height: AppSpacing.sm),
          AppCounter(
            label: l10n.onboardingSmallSessions,
            value: weeklySmallSessions,
            onChanged: onSmallChanged,
          ),
          const SizedBox(height: 8),
          AppCounter(
            label: l10n.onboardingBigSessions,
            value: weeklyBigSessions,
            onChanged: onBigChanged,
          ),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final String label;
  final String value;
  const _RewardRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: AppText.body(label)),
        AppText.monoStrong(value),
      ],
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
            AppText.title(l10n.setupBlocking),
            const SizedBox(height: AppSpacing.sm),
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
        AppButton.secondary(
          l10n.onboardingSelectApps,
          onPressed: onTap,
          width: double.infinity,
          icon: Icons.apps_outlined,
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
