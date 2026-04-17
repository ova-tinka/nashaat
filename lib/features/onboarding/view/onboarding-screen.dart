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
import '../../../shared/logger.dart';
import '../../../shared/utils/screen-time-economy.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  // Step 1 — Exercise Target
  String _username = '';
  int _daysPerWeek = 4;
  int _workoutDurationMinutes = 30;
  int _dailyPhoneHours = 8;
  int _weeklySmallSessions = 2;
  int _weeklyBigSessions = 3;

  // Step 2 — Blocking Preferences
  List<String> _selectedAppPackages = [];

  bool _isSaving = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showProgress = _page > 0;
    final stepLabel = _page == 1 ? 'Step 1 of 2' : (_page == 2 ? 'Step 2 of 2' : '');
    final progressValue = _page == 1 ? 0.5 : 1.0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (showProgress) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                child: Row(
                  children: [
                    Text(
                      stepLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: LinearProgressIndicator(
                  value: progressValue,
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 6,
                ),
              ),
            ] else
              const SizedBox(height: 16),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomePage(
                    onNext: (username) {
                      _username = username;
                      _nextPage();
                    },
                  ),
                  _ExerciseTargetPage(
                    daysPerWeek: _daysPerWeek,
                    workoutDurationMinutes: _workoutDurationMinutes,
                    dailyPhoneHours: _dailyPhoneHours,
                    weeklySmallSessions: _weeklySmallSessions,
                    weeklyBigSessions: _weeklyBigSessions,
                    onDaysChanged: (v) => setState(() => _daysPerWeek = v),
                    onDurationChanged: (v) =>
                        setState(() => _workoutDurationMinutes = v),
                    onDailyHoursChanged: (v) =>
                        setState(() => _dailyPhoneHours = v),
                    onSmallSessionsChanged: (v) =>
                        setState(() => _weeklySmallSessions = v),
                    onBigSessionsChanged: (v) =>
                        setState(() => _weeklyBigSessions = v),
                    onNext: _nextPage,
                  ),
                  _BlockingPreferencesPage(
                    onSkip: _handleFinish,
                    onContinue: (packages) async {
                      _selectedAppPackages = packages;
                      await _handleFinish();
                    },
                    isSaving: _isSaving,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextPage() {
    setState(() => _page++);
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleFinish() async {
    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final repo = RepositoryLocator.instance.profile;
      final weeklyTargetMinutes = _daysPerWeek * _workoutDurationMinutes;

      await repo.updateProfile(
        userId,
        username: _username.trim().isEmpty ? null : _username.trim(),
        weeklyExerciseTargetMinutes: weeklyTargetMinutes,
      );
      await repo.updateScreenTimeSetup(
        userId,
        dailyPhoneHours: _dailyPhoneHours,
        weeklySmallSessions: _weeklySmallSessions,
        weeklyBigSessions: _weeklyBigSessions,
      );

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
          const SnackBar(
              content: Text('Could not save preferences. Please try again.')),
        );
      }
    }
  }
}

// ── Pages ─────────────────────────────────────────────────────────────────────

class _WelcomePage extends StatefulWidget {
  final ValueChanged<String> onNext;
  const _WelcomePage({required this.onNext});

  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Icon(Icons.fitness_center, size: 80, color: cs.primary),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Welcome to Nashaat',
              style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Earn screen time by working out.\nBuild discipline. Build consistency.',
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'What should we call you?',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              labelText: 'Username (optional)',
              hintText: 'e.g. fitnessathlete',
              border: OutlineInputBorder(),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
            ],
            textCapitalization: TextCapitalization.none,
            onSubmitted: (_) => widget.onNext(_ctrl.text),
          ),
          const SizedBox(height: 40),
          FilledButton(
            onPressed: () => widget.onNext(_ctrl.text),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: const Text("Let's Get Started"),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTargetPage extends StatelessWidget {
  final int daysPerWeek;
  final int workoutDurationMinutes;
  final int dailyPhoneHours;
  final int weeklySmallSessions;
  final int weeklyBigSessions;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<int> onDailyHoursChanged;
  final ValueChanged<int> onSmallSessionsChanged;
  final ValueChanged<int> onBigSessionsChanged;
  final VoidCallback onNext;

  const _ExerciseTargetPage({
    required this.daysPerWeek,
    required this.workoutDurationMinutes,
    required this.dailyPhoneHours,
    required this.weeklySmallSessions,
    required this.weeklyBigSessions,
    required this.onDaysChanged,
    required this.onDurationChanged,
    required this.onDailyHoursChanged,
    required this.onSmallSessionsChanged,
    required this.onBigSessionsChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final weeklyTargetMinutes = daysPerWeek * workoutDurationMinutes;

    final rewards = ScreenTimeEconomy.calculateRaw(
      dailyPhoneHours: dailyPhoneHours,
      weeklySmallSessions: weeklySmallSessions,
      weeklyBigSessions: weeklyBigSessions,
    );

    String fmt(int m) {
      final h = m ~/ 60;
      final min = m % 60;
      return h > 0 ? '${h}h ${min}m' : '${min}m';
    }

    const durations = [15, 30, 45, 60, 90];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exercise Target',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'How often and how long do you want to work out?',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          // Days per week
          Text('Days per week',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final day = i + 1;
              final selected = day <= daysPerWeek;
              return GestureDetector(
                onTap: () => onDaysChanged(day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected ? cs.primary : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: tt.labelLarge?.copyWith(
                      color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            '$daysPerWeek day${daysPerWeek == 1 ? '' : 's'} per week',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          // Workout duration
          Text('Workout duration',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: durations.map((d) {
              final selected = d == workoutDurationMinutes;
              return ChoiceChip(
                label: Text('${d}m'),
                selected: selected,
                onSelected: (_) => onDurationChanged(d),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Weekly target: ${fmt(weeklyTargetMinutes)}',
              style: tt.bodyMedium?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Daily phone usage
          Text('Daily phone usage',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: dailyPhoneHours.toDouble(),
                  min: 1,
                  max: 16,
                  divisions: 15,
                  label: '${dailyPhoneHours}h',
                  onChanged: (v) => onDailyHoursChanged(v.round()),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${dailyPhoneHours}h',
                  style:
                      tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Weekly sessions
          Text('Weekly workout sessions',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _SessionCounter(
            label: 'Small sessions',
            sublabel: '1× reward',
            icon: Icons.fitness_center,
            value: weeklySmallSessions,
            onChanged: onSmallSessionsChanged,
          ),
          const SizedBox(height: 8),
          _SessionCounter(
            label: 'Big sessions',
            sublabel: '2× reward',
            icon: Icons.local_fire_department,
            value: weeklyBigSessions,
            onChanged: onBigSessionsChanged,
          ),
          const SizedBox(height: 20),

          if ((weeklySmallSessions + weeklyBigSessions) > 0) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${fmt(rewards.freeMinutes)} free + earn up to '
                '${fmt(rewards.smallRewardMinutes)} per small session '
                'or ${fmt(rewards.bigRewardMinutes)} per big session.',
                style: tt.bodySmall?.copyWith(color: cs.onSecondaryContainer),
              ),
            ),
            const SizedBox(height: 20),
          ],

          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _BlockingPreferencesPage extends StatefulWidget {
  final VoidCallback onSkip;
  final Future<void> Function(List<String> packages) onContinue;
  final bool isSaving;

  const _BlockingPreferencesPage({
    required this.onSkip,
    required this.onContinue,
    required this.isSaving,
  });

  @override
  State<_BlockingPreferencesPage> createState() =>
      _BlockingPreferencesPageState();
}

class _BlockingPreferencesPageState extends State<_BlockingPreferencesPage> {
  final _platform = BlockingPlatformService();
  List<InstalledApp> _installedApps = [];
  final Set<String> _selected = {};
  bool _loadingApps = false;
  bool _iosPickerDone = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _loadApps();
    }
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
      if (count > 0) {
        setState(() => _iosPickerDone = true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set Up App Blocking',
                  style:
                      tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose apps to block when your screen time runs out. You can change this later.',
                  style:
                      tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 28),

                if (Platform.isIOS) ...[
                  FilledButton.tonal(
                    onPressed: _openIosPicker,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Select Apps via Screen Time'),
                  ),
                  if (_iosPickerDone) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: cs.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Apps selected via Screen Time',
                          style: tt.bodyMedium
                              ?.copyWith(color: cs.primary),
                        ),
                      ],
                    ),
                  ],
                ] else ...[
                  if (_loadingApps)
                    const Center(child: CircularProgressIndicator())
                  else if (_installedApps.isEmpty)
                    Text(
                      'No apps found.',
                      style:
                          tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    )
                  else
                    ..._installedApps.map((app) {
                      final checked = _selected.contains(app.packageId);
                      return CheckboxListTile(
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
                        title: Text(app.name),
                        subtitle: Text(
                          app.packageId,
                          style: tt.bodySmall,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
          child: Column(
            children: [
              FilledButton(
                onPressed: widget.isSaving
                    ? null
                    : () => widget.onContinue(_selected.toList()),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: widget.isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
              TextButton(
                onPressed: widget.isSaving ? null : widget.onSkip,
                child: Text(
                  'Skip for Now',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionCounter extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final int value;
  final ValueChanged<int> onChanged;

  const _SessionCounter({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: tt.bodyMedium),
              Text(sublabel,
                  style:
                      tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < 7 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
