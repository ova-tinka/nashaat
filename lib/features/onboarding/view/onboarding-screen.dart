import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/enums.dart';
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

  // Collected values
  String _username = '';
  int _weeklyTargetMinutes = 150;
  String _experience = 'beginner';
  int _dailyPhoneHours = 8;
  int _weeklySmallSessions = 2;
  int _weeklyBigSessions = 3;
  bool _isSaving = false;

  static const _totalPages = 4;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: LinearProgressIndicator(
                value: (_page + 1) / _totalPages,
                borderRadius: BorderRadius.circular(8),
                minHeight: 6,
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomePage(onNext: _nextPage),
                  _UsernamePage(
                    onNext: (username) {
                      _username = username;
                      _nextPage();
                    },
                  ),
                  _GoalPage(
                    weeklyTarget: _weeklyTargetMinutes,
                    experience: _experience,
                    onTargetChanged: (v) =>
                        setState(() => _weeklyTargetMinutes = v),
                    onExperienceChanged: (v) =>
                        setState(() => _experience = v),
                    onNext: _nextPage,
                  ),
                  _PhoneSetupPage(
                    dailyPhoneHours: _dailyPhoneHours,
                    weeklySmallSessions: _weeklySmallSessions,
                    weeklyBigSessions: _weeklyBigSessions,
                    onDailyHoursChanged: (v) =>
                        setState(() => _dailyPhoneHours = v),
                    onSmallSessionsChanged: (v) =>
                        setState(() => _weeklySmallSessions = v),
                    onBigSessionsChanged: (v) =>
                        setState(() => _weeklyBigSessions = v),
                    onFinish: _handleFinish,
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

      await repo.updateProfile(
        userId,
        username: _username.trim().isEmpty ? null : _username.trim(),
        weeklyExerciseTargetMinutes: _weeklyTargetMinutes,
      );
      await repo.updateScreenTimeSetup(
        userId,
        dailyPhoneHours: _dailyPhoneHours,
        weeklySmallSessions: _weeklySmallSessions,
        weeklyBigSessions: _weeklyBigSessions,
      );
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

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, size: 80, color: cs.primary),
          const SizedBox(height: 24),
          Text(
            'Welcome to Nashaat',
            style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Earn screen time by working out.\nBuild discipline. Build consistency.',
            style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              minimumSize: const Size(240, 52),
            ),
            child: const Text("Let's Get Started"),
          ),
        ],
      ),
    );
  }
}

class _UsernamePage extends StatefulWidget {
  final ValueChanged<String> onNext;
  const _UsernamePage({required this.onNext});

  @override
  State<_UsernamePage> createState() => _UsernamePageState();
}

class _UsernamePageState extends State<_UsernamePage> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What should we call you?',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'This is your display name in leaderboards.',
            style: tt.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _ctrl,
            autofocus: true,
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
          const Spacer(),
          FilledButton(
            onPressed: () => widget.onNext(_ctrl.text),
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

class _GoalPage extends StatelessWidget {
  final int weeklyTarget;
  final String experience;
  final ValueChanged<int> onTargetChanged;
  final ValueChanged<String> onExperienceChanged;
  final VoidCallback onNext;

  const _GoalPage({
    required this.weeklyTarget,
    required this.experience,
    required this.onTargetChanged,
    required this.onExperienceChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    const experiences = ['beginner', 'intermediate', 'advanced'];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set your weekly goal',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'How many minutes do you want to train per week?',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '${weeklyTarget}m',
              style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Slider(
            value: weeklyTarget.toDouble(),
            min: 30,
            max: 600,
            divisions: 19,
            onChanged: (v) => onTargetChanged(v.round()),
          ),
          Text(
            '≈ ${weeklyTarget ~/ 60}h ${weeklyTarget % 60}m per week',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Text(
            'Experience level',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: experiences
                .map((e) => ButtonSegment(
                      value: e,
                      label: Text(e[0].toUpperCase() + e.substring(1)),
                    ))
                .toList(),
            selected: {experience},
            onSelectionChanged: (s) => onExperienceChanged(s.first),
          ),
          const SizedBox(height: 48),
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

class _PhoneSetupPage extends StatelessWidget {
  final int dailyPhoneHours;
  final int weeklySmallSessions;
  final int weeklyBigSessions;
  final ValueChanged<int> onDailyHoursChanged;
  final ValueChanged<int> onSmallSessionsChanged;
  final ValueChanged<int> onBigSessionsChanged;
  final VoidCallback onFinish;
  final bool isSaving;

  const _PhoneSetupPage({
    required this.dailyPhoneHours,
    required this.weeklySmallSessions,
    required this.weeklyBigSessions,
    required this.onDailyHoursChanged,
    required this.onSmallSessionsChanged,
    required this.onBigSessionsChanged,
    required this.onFinish,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phone time setup',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'We use this to calculate how much screen time each workout earns.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 28),

          // Daily phone hours
          Text('Daily phone usage',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Center(
            child: Text('${dailyPhoneHours}h/day',
                style: tt.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          Slider(
            value: dailyPhoneHours.toDouble(),
            min: 1,
            max: 16,
            divisions: 15,
            label: '${dailyPhoneHours}h',
            onChanged: (v) => onDailyHoursChanged(v.round()),
          ),
          const SizedBox(height: 24),

          // Session counts
          Text('Weekly workout sessions',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
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
          const SizedBox(height: 28),

          // Live preview
          if ((weeklySmallSessions + weeklyBigSessions) > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your weekly economy',
                      style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimaryContainer)),
                  const SizedBox(height: 8),
                  Text(
                    '${fmt(rewards.freeMinutes)} free + earn up to '
                    '${fmt(rewards.smallRewardMinutes)} per small session '
                    'or ${fmt(rewards.bigRewardMinutes)} per big session.',
                    style: tt.bodyMedium
                        ?.copyWith(color: cs.onPrimaryContainer),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],

          FilledButton(
            onPressed: isSaving ? null : onFinish,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Let's Go!"),
          ),
        ],
      ),
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
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed:
              value > 0 ? () => onChanged(value - 1) : null,
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

