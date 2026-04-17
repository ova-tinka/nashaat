import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/blocking-rule-entity.dart';
import '../../../core/entities/enums.dart';
import '../../../infra/blocking/blocking-platform-service.dart';
import '../../../infra/permissions/permission-service.dart';
import '../../../infra/repository-locator.dart';
import '../../../main.dart';
import '../../../shared/design/atoms/app-chip.dart';
import '../../../shared/design/molecules/app-counter.dart';
import '../../../shared/design/organisms/app-step-scaffold.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../../../shared/logger.dart';
import '../../../shared/utils/screen-time-economy.dart';

// Total steps: 0-based index, 6 steps total
const _kTotalSteps = 6;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  // Step 0 — Username
  String _username = '';
  // Step 1 — Days per week
  int _daysPerWeek = 4;
  // Step 2 — Workout duration
  int _workoutDurationMinutes = 30;
  // Step 3 — Daily phone hours
  int _dailyPhoneHours = 8;
  // Step 4 — Reward preview (read-only + optional session counters)
  int _weeklySmallSessions = 2;
  int _weeklyBigSessions = 3;
  // Step 5 — Blocking preferences
  List<String> _selectedAppPackages = [];

  bool _isSaving = false;

  void _goNext() {
    if (_step < _kTotalSteps - 1) {
      setState(() => _step++);
    }
  }

  Future<void> _handleFinish({List<String>? packages}) async {
    if (packages != null) _selectedAppPackages = packages;
    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final repo = RepositoryLocator.instance.profile;
      final weeklyTargetMinutes = _daysPerWeek * _workoutDurationMinutes;

      await repo.updateProfile(userId,
          username: _username.trim().isEmpty ? null : _username.trim(),
          weeklyExerciseTargetMinutes: weeklyTargetMinutes);
      await repo.updateScreenTimeSetup(userId,
          dailyPhoneHours: _dailyPhoneHours,
          weeklySmallSessions: _weeklySmallSessions,
          weeklyBigSessions: _weeklyBigSessions);

      if (_selectedAppPackages.isNotEmpty) {
        try {
          final blockingRepo = RepositoryLocator.instance.blocking;
          for (final pkg in _selectedAppPackages) {
            await blockingRepo.createRule(BlockingRuleEntity(
              id: '',
              userId: userId,
              itemType: ItemType.app,
              itemIdentifier: pkg,
              status: RuleStatus.active,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));
          }
          final platform = BlockingPlatformService();
          final permService = PermissionService(platform);
          final perms = await permService.checkAll();
          if (!perms.isFullyGranted) {
            for (final p in perms.missing) {
              await permService.request(p);
            }
          }
        } catch (e) {
          Log.error('OnboardingScreen.blocking', e);
        }
      }

      await repo.updateStatus(userId, UserStatus.onboarded);
      Log.auth('onboarding complete');
      if (mounted) appCoordinator.showDashboard();
    } catch (e) {
      Log.error('OnboardingScreen', e);
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save preferences. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) setState(() => _step--);
      },
      child: _buildStep(context),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return AppStepScaffold(
          totalSteps: _kTotalSteps,
          currentStep: 0,
          nextLabel: "Let's Go",
          onNext: _goNext,
          body: _WelcomeStep(
            initial: _username,
            onChanged: (v) => _username = v,
          ),
        );
      case 1:
        return AppStepScaffold(
          totalSteps: _kTotalSteps,
          currentStep: 1,
          onNext: _goNext,
          body: _DaysPerWeekStep(
            value: _daysPerWeek,
            onChanged: (v) => setState(() => _daysPerWeek = v),
          ),
        );
      case 2:
        return AppStepScaffold(
          totalSteps: _kTotalSteps,
          currentStep: 2,
          onNext: _goNext,
          body: _WorkoutDurationStep(
            value: _workoutDurationMinutes,
            onChanged: (v) => setState(() => _workoutDurationMinutes = v),
          ),
        );
      case 3:
        return AppStepScaffold(
          totalSteps: _kTotalSteps,
          currentStep: 3,
          onNext: _goNext,
          body: _DailyPhoneHoursStep(
            value: _dailyPhoneHours,
            onChanged: (v) => setState(() => _dailyPhoneHours = v),
          ),
        );
      case 4:
        return AppStepScaffold(
          totalSteps: _kTotalSteps,
          currentStep: 4,
          onNext: _goNext,
          body: _RewardPreviewStep(
            daysPerWeek: _daysPerWeek,
            workoutDurationMinutes: _workoutDurationMinutes,
            dailyPhoneHours: _dailyPhoneHours,
            weeklySmallSessions: _weeklySmallSessions,
            weeklyBigSessions: _weeklyBigSessions,
            onSmallChanged: (v) => setState(() => _weeklySmallSessions = v),
            onBigChanged: (v) => setState(() => _weeklyBigSessions = v),
          ),
        );
      case 5:
        return _BlockingStep(
          isSaving: _isSaving,
          onContinue: (packages) => _handleFinish(packages: packages),
          onSkip: () => _handleFinish(),
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
  const _WelcomeStep({required this.initial, required this.onChanged});

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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WELCOME TO\nNASHAAT', style: AppTypography.display),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Earn screen time by working out.\nBuild discipline. Build consistency.',
            style: AppTypography.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('What should we call you?', style: AppTypography.heading.copyWith(fontSize: 15)),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              labelText: 'Username (optional)',
              hintText: 'e.g. fitnessathlete',
            ),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]'))],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOW MANY DAYS\nPER WEEK?', style: AppTypography.display.copyWith(fontSize: 28)),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final day = i + 1;
              return AppDayChip(
                label: '$day',
                selected: day <= value,
                onTap: () => onChanged(day),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '$value day${value == 1 ? '' : 's'} per week',
            style: AppTypography.mono.copyWith(color: AppColors.inkMuted),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOW LONG PER\nWORKOUT?', style: AppTypography.display.copyWith(fontSize: 28)),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _durations.map((d) {
              return AppSelectChip(
                label: '${d}m',
                selected: d == value,
                onTap: () => onChanged(d),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DAILY PHONE\nUSAGE?', style: AppTypography.display.copyWith(fontSize: 28)),
          const SizedBox(height: AppSpacing.sm),
          Text('We use this to calibrate your screen time economy.', style: AppTypography.bodyMuted),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              '${value}h',
              style: AppTypography.display.copyWith(fontSize: 64),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Slider(
            value: value.toDouble(),
            min: 1, max: 16, divisions: 15,
            label: '${value}h',
            onChanged: (v) => onChanged(v.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1h', style: AppTypography.labelMuted),
              Text('16h', style: AppTypography.labelMuted),
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
    final rewards = ScreenTimeEconomy.calculateRaw(
      dailyPhoneHours: dailyPhoneHours,
      weeklySmallSessions: weeklySmallSessions,
      weeklyBigSessions: weeklyBigSessions,
    );
    final weeklyTargetMinutes = daysPerWeek * workoutDurationMinutes;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR REWARD\nPREVIEW', style: AppTypography.display.copyWith(fontSize: 28)),
          const SizedBox(height: AppSpacing.lg),

          // Summary block
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            color: AppColors.paperAlt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RewardRow('Weekly target', _fmt(weeklyTargetMinutes)),
                const SizedBox(height: 8),
                _RewardRow('Free time / week', _fmt(rewards.freeMinutes)),
                const SizedBox(height: 8),
                _RewardRow('Per small session', _fmt(rewards.smallRewardMinutes)),
                const SizedBox(height: 8),
                _RewardRow('Per big session', _fmt(rewards.bigRewardMinutes)),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          Text('Weekly session split', style: AppTypography.heading.copyWith(fontSize: 15)),
          const SizedBox(height: AppSpacing.sm),
          AppCounter(label: 'Small sessions (1×)', value: weeklySmallSessions, onChanged: onSmallChanged),
          const SizedBox(height: 8),
          AppCounter(label: 'Big sessions (2×)', value: weeklyBigSessions, onChanged: onBigChanged),
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
        Expanded(child: Text(label, style: AppTypography.body)),
        Text(value, style: AppTypography.monoStrong),
      ],
    );
  }
}

// ── Step 5 — Blocking preferences ────────────────────────────────────────────

class _BlockingStep extends StatefulWidget {
  final bool isSaving;
  final Future<void> Function(List<String>) onContinue;
  final VoidCallback onSkip;

  const _BlockingStep({required this.isSaving, required this.onContinue, required this.onSkip});

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
      setState(() => _installedApps = apps);
    } catch (_) {
    } finally {
      setState(() => _loadingApps = false);
    }
  }

  Future<void> _openIosPicker() async {
    try {
      final count = await _platform.presentIosPicker();
      if (count > 0) setState(() => _iosPickerDone = true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AppStepScaffold(
      totalSteps: _kTotalSteps,
      currentStep: 5,
      nextLabel: 'Finish Setup',
      isLoading: widget.isSaving,
      onNext: () => widget.onContinue(_selected.toList()),
      skipLabel: 'Skip for Now',
      onSkip: widget.isSaving ? null : widget.onSkip,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SET UP APP\nBLOCKING', style: AppTypography.display.copyWith(fontSize: 28)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Choose apps to block when your screen time runs out.\nYou can change this later.',
              style: AppTypography.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (Platform.isIOS) ...[
              _IosPickerSection(iosDone: _iosPickerDone, onTap: _openIosPicker),
            ] else ...[
              if (_loadingApps)
                const Center(child: CircularProgressIndicator(color: AppColors.ink))
              else if (_installedApps.isEmpty)
                Text('No apps found.', style: AppTypography.bodyMuted)
              else
                ..._installedApps.map((app) {
                  final checked = _selected.contains(app.packageId);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) { _selected.add(app.packageId); }
                        else { _selected.remove(app.packageId); }
                      });
                    },
                    title: Text(app.name, style: AppTypography.body),
                    subtitle: Text(app.packageId, style: AppTypography.labelMuted),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.ink, width: 1),
            ),
            child: Text('Select Apps via Screen Time', style: AppTypography.label.copyWith(fontSize: 14), textAlign: TextAlign.center),
          ),
        ),
        if (iosDone) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(width: 8, height: 8, color: AppColors.acid),
              const SizedBox(width: 8),
              Text('Apps selected via Screen Time', style: AppTypography.body),
            ],
          ),
        ],
      ],
    );
  }
}
