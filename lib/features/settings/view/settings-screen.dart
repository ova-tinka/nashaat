import 'package:flutter/material.dart';

import '../../../infra/repository-locator.dart';
import '../../../main.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-divider.dart';
import '../../../shared/design/molecules/app-card.dart';
import '../../../shared/design/molecules/app-counter.dart';
import '../../../shared/design/molecules/app-section-header.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
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
    if (_vm.isDeleted) {
      appCoordinator.showLogin();
      return;
    }
    final profile = _vm.profile;
    if (profile != null && !_edited) {
      _usernameCtrl.text = profile.username ?? '';
      _firstNameCtrl.text = profile.firstName ?? '';
      _lastNameCtrl.text = profile.lastName ?? '';
      _weeklyTargetMinutes = profile.weeklyExerciseTargetMinutes;
    }
    if (profile != null && !_screenTimeEdited) {
      _dailyPhoneHours = profile.dailyPhoneHours > 0 ? profile.dailyPhoneHours : 8;
      _weeklySmallSessions = profile.weeklySmallSessions;
      _weeklyBigSessions = profile.weeklyBigSessions;
    }
    if (_vm.successMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_vm.successMessage!)),
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
          backgroundColor: AppColors.paper,
          appBar: AppBar(
            title: Text('SETTINGS', style: AppTypography.sectionHeader.copyWith(fontSize: 13, letterSpacing: 2)),
          ),
          body: _vm.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.ink))
              : _buildBody(context),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.xl),
      children: [
        if (_vm.error != null)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.errorMuted,
              border: Border.all(color: AppColors.error, width: 1),
            ),
            child: Text(_vm.error!, style: AppTypography.body.copyWith(color: AppColors.error)),
          ),

        // Profile
        AppSectionHeader('Profile'),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            children: [
              _SettingsField(controller: _usernameCtrl, label: 'Username', hint: 'e.g. fitnesswarrior', onChanged: (_) => _edited = true),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(child: _SettingsField(controller: _firstNameCtrl, label: 'First name', onChanged: (_) => _edited = true)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _SettingsField(controller: _lastNameCtrl, label: 'Last name', onChanged: (_) => _edited = true)),
                ],
              ),
            ],
          ),
        ),

        // Training goals
        AppSectionHeader('Training Goals'),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weekly training target', style: AppTypography.body),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _weeklyTargetMinutes.toDouble(),
                      min: 30, max: 600, divisions: 19,
                      label: '${_weeklyTargetMinutes}m',
                      onChanged: (v) { setState(() => _weeklyTargetMinutes = v.round()); _edited = true; },
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text('${_weeklyTargetMinutes}m', style: AppTypography.monoStrong, textAlign: TextAlign.right),
                  ),
                ],
              ),
              Text(
                'Target: ${_weeklyTargetMinutes ~/ 60}h ${_weeklyTargetMinutes % 60}m per week.',
                style: AppTypography.labelMuted,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton.primary('Save Changes', onPressed: _vm.isSaving ? null : _handleSave, isLoading: _vm.isSaving, width: double.infinity),

        // Screen time economy
        AppSectionHeader('Screen Time Economy'),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Daily phone usage', style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _dailyPhoneHours.toDouble(),
                      min: 1, max: 16, divisions: 15,
                      label: '${_dailyPhoneHours}h',
                      onChanged: (v) { setState(() => _dailyPhoneHours = v.round()); _screenTimeEdited = true; },
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text('${_dailyPhoneHours}h', style: AppTypography.monoStrong, textAlign: TextAlign.right),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Weekly sessions', style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.sm),
              AppCounter(
                label: 'Small (1×)',
                value: _weeklySmallSessions,
                onChanged: (v) { setState(() => _weeklySmallSessions = v); _screenTimeEdited = true; },
              ),
              const SizedBox(height: 6),
              AppCounter(
                label: 'Big (2×)',
                value: _weeklyBigSessions,
                onChanged: (v) { setState(() => _weeklyBigSessions = v); _screenTimeEdited = true; },
              ),
              const SizedBox(height: AppSpacing.md),
              Builder(builder: (context) {
                final rewards = ScreenTimeEconomy.calculateRaw(
                  dailyPhoneHours: _dailyPhoneHours,
                  weeklySmallSessions: _weeklySmallSessions,
                  weeklyBigSessions: _weeklyBigSessions,
                );
                String fmt(int m) {
                  final h = m ~/ 60; final min = m % 60;
                  return h > 0 ? '${h}h ${min}m' : '${min}m';
                }
                if (rewards.smallRewardMinutes == 0) return const SizedBox.shrink();
                return Text(
                  'Small = ${fmt(rewards.smallRewardMinutes)}  ·  Big = ${fmt(rewards.bigRewardMinutes)}  ·  Free = ${fmt(rewards.freeMinutes)}/week',
                  style: AppTypography.mono.copyWith(color: AppColors.inkMuted, fontSize: 12),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton.secondary(
          'Save Screen Time Setup',
          onPressed: _vm.isSaving ? null : _handleSaveScreenTime,
          isLoading: _vm.isSaving,
          width: double.infinity,
        ),

        // Premium
        AppSectionHeader('Premium'),
        Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.acid, width: 3)),
          ),
          child: AppCard(
            backgroundColor: AppColors.paperAlt,
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('NASHAAT VIP', style: AppTypography.sectionHeader.copyWith(fontSize: 13, letterSpacing: 1.5, color: AppColors.ink)),
                    const SizedBox(width: 8),
                    Container(width: 8, height: 8, color: AppColors.acid),
                  ],
                ),
                const SizedBox(height: 10),
                ...[
                  'AI-generated workout plans',
                  'Advanced progress analytics',
                  'Expanded exercise library',
                  'Priority support',
                ].map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 5, height: 5, color: AppColors.acid),
                      const SizedBox(width: 10),
                      Text(f, style: AppTypography.body),
                    ],
                  ),
                )),
                const SizedBox(height: AppSpacing.md),
                AppButton.acid(
                  'Upgrade to VIP',
                  onPressed: () => Navigator.pushNamed(context, '/subscription'),
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ),

        // Account
        AppSectionHeader('Account'),
        AppCard(
          child: Column(
            children: [
              _AccountTile(icon: Icons.lock_reset, label: 'Change Password', onTap: () => _showChangePasswordDialog(context)),
              const AppDivider(indent: 16),
              _AccountTile(icon: Icons.logout, label: 'Sign Out', onTap: () => _confirmSignOut(context)),
              const AppDivider(indent: 16),
              _AccountTile(
                icon: Icons.delete_outline,
                label: 'Delete Account',
                onTap: () => _confirmDeleteAccount(context),
                destructive: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.base),
        Center(child: Text('Nashaat v1.0.0', style: AppTypography.labelMuted)),
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
      username: _usernameCtrl.text.trim().isEmpty ? null : _usernameCtrl.text.trim(),
      firstName: _firstNameCtrl.text.trim().isEmpty ? null : _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim().isEmpty ? null : _lastNameCtrl.text.trim(),
      weeklyExerciseTargetMinutes: _weeklyTargetMinutes,
    );
    _edited = false;
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Sign Out', style: AppTypography.heading),
        content: Text('Are you sure you want to sign out?', style: AppTypography.body),
        actions: [
          AppButton.ghost('Cancel', onPressed: () => Navigator.pop(context, false)),
          const SizedBox(width: 8),
          AppButton.primary('Sign Out', onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (ok == true) {
      await _vm.signOut();
      if (mounted) appCoordinator.showLogin();
    }
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text('Change Password', style: AppTypography.heading),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: newPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
                  validator: (v) => (v == null || v.length < 8) ? 'Password must be at least 8 characters' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm Password'),
                  validator: (v) => v != newPassCtrl.text ? 'Passwords do not match' : null,
                ),
              ],
            ),
          ),
          actions: [
            AppButton.ghost('Cancel', onPressed: () => Navigator.pop(dialogCtx)),
            const SizedBox(width: 8),
            AppButton.primary(
              'Update',
              onPressed: _vm.isSaving ? null : () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogCtx);
                await _vm.changePassword(newPassCtrl.text);
              },
            ),
          ],
        ),
      ),
    );
    newPassCtrl.dispose();
    confirmPassCtrl.dispose();
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final step1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Your Account?', style: AppTypography.heading),
        content: Text(
          'This action is permanent and cannot be undone. All your data, workout history, and screen time balance will be permanently deleted.',
          style: AppTypography.body,
        ),
        actions: [
          AppButton.ghost('Cancel', onPressed: () => Navigator.pop(context, false)),
          const SizedBox(width: 8),
          AppButton.destructive('Delete Permanently', onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (step1 != true || !mounted) return;

    final confirmCtrl = TextEditingController();
    // ignore: use_build_context_synchronously
    final step2 = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text('Confirm Deletion', style: AppTypography.heading),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type DELETE to confirm:', style: AppTypography.body),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'DELETE'),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            AppButton.ghost('Cancel', onPressed: () => Navigator.pop(dialogCtx, false)),
            const SizedBox(width: 8),
            AppButton.destructive(
              'Delete Account',
              onPressed: confirmCtrl.text == 'DELETE' ? () => Navigator.pop(dialogCtx, true) : null,
            ),
          ],
        ),
      ),
    );
    confirmCtrl.dispose();
    if (step2 == true) await _vm.deleteAccount();
  }
}

class _SettingsField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final ValueChanged<String>? onChanged;

  const _SettingsField({required this.controller, required this.label, this.hint, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
      textCapitalization: TextCapitalization.words,
      onChanged: onChanged,
    );
  }
}

class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _AccountTile({required this.icon, required this.label, required this.onTap, this.destructive = false});

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppTypography.body.copyWith(color: color))),
            Icon(Icons.chevron_right, size: 18, color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }
}
