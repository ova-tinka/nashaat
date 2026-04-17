import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../infra/repository-locator.dart';
import '../../../main.dart';
import '../../../shared/utils/screen-time-economy.dart';
import '../view-model/settings-view-model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsViewModel _vm;
  final _usernameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  int _weeklyTargetMinutes = 120;
  int _dailyPhoneHours = 8;
  int _weeklySmallSessions = 2;
  int _weeklyBigSessions = 3;
  bool _edited = false;
  bool _screenTimeEdited = false;

  @override
  void initState() {
    super.initState();
    _vm = SettingsViewModel(
      profileRepo: RepositoryLocator.instance.profile,
      authRepo: RepositoryLocator.instance.auth,
    );
    _vm.addListener(_onVmChanged);
    _vm.load();
  }

  void _onVmChanged() {
    final profile = _vm.profile;
    if (profile != null && !_edited) {
      _usernameCtrl.text = profile.username ?? '';
      _firstNameCtrl.text = profile.firstName ?? '';
      _lastNameCtrl.text = profile.lastName ?? '';
      _weeklyTargetMinutes = profile.weeklyExerciseTargetMinutes;
    }
    if (profile != null && !_screenTimeEdited) {
      _dailyPhoneHours =
          profile.dailyPhoneHours > 0 ? profile.dailyPhoneHours : 8;
      _weeklySmallSessions = profile.weeklySmallSessions;
      _weeklyBigSessions = profile.weeklyBigSessions;
    }
    if (_vm.successMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_vm.successMessage!),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _vm.clearMessages();
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _usernameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            centerTitle: false,
          ),
          body: _vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(context),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        if (_vm.error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_vm.error!,
                style: TextStyle(color: cs.onErrorContainer)),
          ),

        // Profile section
        _SectionHeader(title: 'Profile'),
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _TextField(
                  controller: _usernameCtrl,
                  label: 'Username',
                  hint: 'e.g. fitnesswarrior',
                  onChanged: (_) => _edited = true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TextField(
                        controller: _firstNameCtrl,
                        label: 'First name',
                        onChanged: (_) => _edited = true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TextField(
                        controller: _lastNameCtrl,
                        label: 'Last name',
                        onChanged: (_) => _edited = true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Training goals section
        _SectionHeader(title: 'Training Goals'),
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Weekly training target',
                    style: tt.bodyMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _weeklyTargetMinutes.toDouble(),
                        min: 30,
                        max: 600,
                        divisions: 19,
                        label: '${_weeklyTargetMinutes}m',
                        onChanged: (v) {
                          setState(
                              () => _weeklyTargetMinutes = v.round());
                          _edited = true;
                        },
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${_weeklyTargetMinutes}m',
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Aim for at least ${_weeklyTargetMinutes ~/ 60}h ${_weeklyTargetMinutes % 60}m of training per week.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Save profile button
        FilledButton(
          onPressed: _vm.isSaving ? null : _handleSave,
          child: _vm.isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Changes'),
        ),
        const SizedBox(height: 24),

        // Screen time economy section
        _SectionHeader(title: 'Screen Time Economy'),
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily phone usage',
                    style: tt.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _dailyPhoneHours.toDouble(),
                        min: 1,
                        max: 16,
                        divisions: 15,
                        label: '${_dailyPhoneHours}h',
                        onChanged: (v) {
                          setState(() => _dailyPhoneHours = v.round());
                          _screenTimeEdited = true;
                        },
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${_dailyPhoneHours}h',
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Weekly sessions',
                    style: tt.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                _SettingsSessionCounter(
                  label: 'Small  (1×)',
                  value: _weeklySmallSessions,
                  onChanged: (v) {
                    setState(() => _weeklySmallSessions = v);
                    _screenTimeEdited = true;
                  },
                ),
                const SizedBox(height: 4),
                _SettingsSessionCounter(
                  label: 'Big  (2×)',
                  value: _weeklyBigSessions,
                  onChanged: (v) {
                    setState(() => _weeklyBigSessions = v);
                    _screenTimeEdited = true;
                  },
                ),
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  final rewards = ScreenTimeEconomy.calculateRaw(
                    dailyPhoneHours: _dailyPhoneHours,
                    weeklySmallSessions: _weeklySmallSessions,
                    weeklyBigSessions: _weeklyBigSessions,
                  );
                  String fmt(int m) {
                    final h = m ~/ 60;
                    final min = m % 60;
                    return h > 0 ? '${h}h ${min}m' : '${min}m';
                  }

                  if (rewards.smallRewardMinutes == 0) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    'Small = ${fmt(rewards.smallRewardMinutes)}  ·  '
                    'Big = ${fmt(rewards.bigRewardMinutes)}  ·  '
                    'Free = ${fmt(rewards.freeMinutes)}/week',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: _vm.isSaving ? null : _handleSaveScreenTime,
          child: const Text('Save Screen Time Setup'),
        ),
        const SizedBox(height: 24),

        // Premium section
        _SectionHeader(title: 'Premium'),
        Card(
          elevation: 0,
          color: cs.tertiaryContainer,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: cs.onTertiaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      'Nashaat VIP',
                      style: tt.titleMedium?.copyWith(
                        color: cs.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...[
                  'AI-generated workout plans',
                  'Advanced progress analytics',
                  'Expanded exercise library',
                  'Priority support',
                ].map(
                  (f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 16,
                            color: cs.onTertiaryContainer),
                        const SizedBox(width: 8),
                        Text(
                          f,
                          style: tt.bodyMedium
                              ?.copyWith(color: cs.onTertiaryContainer),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.tertiary,
                    foregroundColor: cs.onTertiary,
                  ),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/subscription',
                  ),
                  child: const Text('Upgrade to VIP'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Account section
        _SectionHeader(title: 'Account'),
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign Out'),
                onTap: () => _confirmSignOut(context),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              Divider(height: 1, color: cs.outlineVariant),
              ListTile(
                leading: Icon(Icons.delete_outline, color: cs.error),
                title: Text('Delete Account',
                    style: TextStyle(color: cs.error)),
                onTap: () => _confirmDeleteAccount(context),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Version info
        Center(
          child: Text(
            'Nashaat v1.0.0',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSaveScreenTime() async {
    await _vm.updateScreenTimeSetup(
      dailyPhoneHours: _dailyPhoneHours,
      weeklySmallSessions: _weeklySmallSessions,
      weeklyBigSessions: _weeklyBigSessions,
    );
    _screenTimeEdited = false;
  }

  Future<void> _handleSave() async {
    await _vm.updateProfile(
      username: _usernameCtrl.text.trim().isEmpty
          ? null
          : _usernameCtrl.text.trim(),
      firstName: _firstNameCtrl.text.trim().isEmpty
          ? null
          : _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim().isEmpty
          ? null
          : _lastNameCtrl.text.trim(),
      weeklyExerciseTargetMinutes: _weeklyTargetMinutes,
    );
    _edited = false;
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _vm.signOut();
      if (mounted) appCoordinator.showLogin();
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Account deletion requires contacting support. Please email support@nashaat.app to request account deletion.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSessionCounter extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _SettingsSessionCounter({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: tt.bodyMedium)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          visualDensity: VisualDensity.compact,
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: value < 7 ? () => onChanged(value + 1) : null,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final ValueChanged<String>? onChanged;

  const _TextField({
    required this.controller,
    required this.label,
    this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      textCapitalization: TextCapitalization.words,
      onChanged: onChanged,
    );
  }
}
