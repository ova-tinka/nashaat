import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/blocking-rule-entity.dart';
import '../../../core/entities/enums.dart';
import '../../../infra/blocking/blocking-platform-service.dart';
import '../../../infra/repository-locator.dart';
import '../../../main.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-divider.dart';
import '../../../shared/design/molecules/app-card.dart';
import '../../../shared/design/molecules/app-section-header.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../../settings/view/settings-screen.dart';
import '../coordinator/blocking-coordinator.dart';
import '../view-model/blocking-view-model.dart';
import '../view-model/focus-view-model.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  late final FocusViewModel _vm;
  late final BlockingCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final platform = BlockingPlatformService();
    _vm = FocusViewModel(
      profileRepo: RepositoryLocator.instance.profile,
      txnRepo: RepositoryLocator.instance.screenTimeTransaction,
      platform: platform,
      blockingRepo: RepositoryLocator.instance.blocking,
      emergencyBreakRepo: RepositoryLocator.instance.emergencyBreak,
      userId: userId,
    );
    _coordinator = BlockingCoordinator(appCoordinator);
    _vm.initialize();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_vm, _vm.blockingVm]),
      builder: (context, _) {
        final bvm = _vm.blockingVm;
        return Scaffold(
          backgroundColor: AppColors.paper,
          appBar: AppBar(
            title: Text('FOCUS', style: AppTypography.sectionHeader.copyWith(fontSize: 13, letterSpacing: 2)),
          ),
          body: _vm.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.ink))
              : RefreshIndicator(
                  color: AppColors.ink,
                  onRefresh: () async {
                    await _vm.refresh();
                    await bvm.initialize();
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    children: [
                      if (_vm.error != null)
                        _ErrorBanner(message: _vm.error!, onDismiss: _vm.clearError),
                      if (bvm.error != null)
                        _ErrorBanner(message: bvm.error!, onDismiss: bvm.clearError),

                      _StatusCard(vm: _vm),
                      const SizedBox(height: AppSpacing.base),

                      if (_vm.balanceMinutes == 0 && bvm.isBlockingActive) ...[
                        _LockActionCard(bvm: bvm, onStartWorkout: () => appCoordinator.showDashboard()),
                        const SizedBox(height: AppSpacing.base),
                      ],

                      if (_vm.isConfigured) ...[
                        _RewardsPreview(vm: _vm),
                        const SizedBox(height: AppSpacing.base),
                      ],
                      if (!_vm.isConfigured)
                        _SetupPrompt(onSetup: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),

                      AppSectionHeader('Blocked Apps'),
                      const SizedBox(height: AppSpacing.sm),

                      if (!bvm.permissions.isFullyGranted)
                        _PermissionsSection(vm: bvm)
                      else ...[
                        _BlockingToggle(vm: bvm),
                        const SizedBox(height: AppSpacing.md),
                        _BlockedAppsList(
                          vm: bvm,
                          onAddApp: () => _coordinator.showAppPicker(context, bvm),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

// ── Status card ───────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final FocusViewModel vm;
  const _StatusCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final balance = vm.balanceMinutes;
    final hours = balance ~/ 60;
    final mins = balance % 60;
    final balanceLabel = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    final unblocked = vm.appsUnblocked;
    final bg = unblocked ? AppColors.acid : AppColors.errorMuted;
    final fg = unblocked ? AppColors.ink : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(unblocked ? Icons.lock_open_outlined : Icons.lock_outlined, color: fg, size: 16),
              const SizedBox(width: 8),
              Text(unblocked ? 'Apps unblocked' : 'Apps blocked', style: AppTypography.label.copyWith(color: fg)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            balance > 0 ? balanceLabel : 'No balance',
            style: AppTypography.display.copyWith(color: fg),
          ),
          const SizedBox(height: 4),
          Text(
            balance > 0
                ? unblocked ? 'Draining while blocked apps are in use' : 'Earn more by completing workouts'
                : 'Complete a workout to earn screen time',
            style: AppTypography.bodyMuted.copyWith(color: fg.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

// ── Permissions section ───────────────────────────────────────────────────────

class _PermissionsSection extends StatelessWidget {
  final BlockingViewModel vm;
  const _PermissionsSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.errorMuted,
        border: Border.all(color: AppColors.error, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
              const SizedBox(width: 8),
              Text('Permissions Required', style: AppTypography.heading.copyWith(fontSize: 15, color: AppColors.error)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Nashaat needs the following permissions to block apps.', style: AppTypography.body.copyWith(color: AppColors.error)),
          const SizedBox(height: AppSpacing.md),
          ...vm.permissions.missing.map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.label, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600, color: AppColors.error)),
                        Text(p.description, style: AppTypography.labelMuted.copyWith(color: AppColors.error)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppButton.secondary('Grant', onPressed: () => vm.requestPermission(p)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Blocking toggle ───────────────────────────────────────────────────────────

class _BlockingToggle extends StatelessWidget {
  final BlockingViewModel vm;
  const _BlockingToggle({required this.vm});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Blocking Active', style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  vm.isBlockingActive
                      ? '${vm.activeRules.length} app(s) currently blocked.'
                      : 'Toggle on to start blocking selected apps.',
                  style: AppTypography.labelMuted,
                ),
              ],
            ),
          ),
          Switch(
            value: vm.isBlockingActive,
            onChanged: vm.rules.isEmpty ? null : (on) => on ? vm.activateBlocking() : vm.deactivateBlocking(),
          ),
        ],
      ),
    );
  }
}

// ── Blocked apps list ─────────────────────────────────────────────────────────

class _BlockedAppsList extends StatelessWidget {
  final BlockingViewModel vm;
  final VoidCallback onAddApp;
  const _BlockedAppsList({required this.vm, required this.onAddApp});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (vm.rules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.inkMuted, size: 16),
                const SizedBox(width: 8),
                Text('No apps in your block list yet.', style: AppTypography.bodyMuted),
              ],
            ),
          )
        else ...[
          ...vm.rules.map((rule) => _AppRuleCard(rule: rule, vm: vm, onModify: onAddApp)),
          const SizedBox(height: 8),
        ],
        if (!vm.isIos || !vm.rules.any((r) => r.itemIdentifier.startsWith('ios_selection:')))
          AppButton.secondary('Add App', onPressed: onAddApp, width: double.infinity, icon: Icons.add),
      ],
    );
  }
}

class _AppRuleCard extends StatelessWidget {
  final BlockingRuleEntity rule;
  final BlockingViewModel vm;
  final VoidCallback? onModify;
  const _AppRuleCard({required this.rule, required this.vm, this.onModify});

  bool get _isIosSelection => rule.itemIdentifier.startsWith('ios_selection:');

  @override
  Widget build(BuildContext context) {
    if (_isIosSelection) return _buildIosCard(context);
    final isActive = rule.status == RuleStatus.active;
    final shortName = rule.itemIdentifier.split('.').last;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                color: AppColors.paperAlt,
                alignment: Alignment.center,
                child: Text(shortName.substring(0, 1).toUpperCase(), style: AppTypography.monoStrong),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shortName, style: AppTypography.body.copyWith(fontWeight: FontWeight.w500)),
                    Text(rule.itemIdentifier, style: AppTypography.labelMuted, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Switch(value: isActive, onChanged: (_) => vm.toggleRule(rule.id)),
              GestureDetector(
                onTap: () => _confirmDelete(context),
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIosCard(BuildContext context) {
    final count = rule.itemIdentifier.split(':').last;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(width: 32, height: 32, color: AppColors.paperAlt, alignment: Alignment.center,
                child: const Icon(Icons.phone_iphone, size: 16, color: AppColors.ink),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Screen Time selection', style: AppTypography.body.copyWith(fontWeight: FontWeight.w500)),
                    Text('$count item(s) via iOS Screen Time', style: AppTypography.labelMuted),
                  ],
                ),
              ),
              TextButton(onPressed: onModify, child: Text('Modify', style: AppTypography.label)),
              GestureDetector(
                onTap: () => _confirmDelete(context),
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final label = _isIosSelection ? 'Screen Time selection' : rule.itemIdentifier.split('.').last;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove', style: AppTypography.heading),
        content: Text('Remove "$label" from your block list?', style: AppTypography.body),
        actions: [
          AppButton.ghost('Cancel', onPressed: () => Navigator.pop(context, false)),
          const SizedBox(width: 8),
          AppButton.destructive('Remove', onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (confirmed == true) await vm.removeRule(rule.id);
  }
}

// ── Rewards preview ───────────────────────────────────────────────────────────

class _RewardsPreview extends StatelessWidget {
  final FocusViewModel vm;
  const _RewardsPreview({required this.vm});

  String _fmt(int minutes) {
    final h = minutes ~/ 60; final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final r = vm.rewards;
    final p = vm.profile!;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("This Week's Economy", style: AppTypography.heading.copyWith(fontSize: 15)),
          const SizedBox(height: AppSpacing.md),
          _EcoRow('Daily phone usage', '${p.dailyPhoneHours}h'),
          _EcoRow('Free baseline (20%)', _fmt(r.freeMinutes)),
          const AppDivider(),
          const SizedBox(height: 4),
          _EcoRow('Small session reward', _fmt(r.smallRewardMinutes)),
          _EcoRow('Big session reward', _fmt(r.bigRewardMinutes)),
          const AppDivider(),
          const SizedBox(height: 4),
          _EcoRow(
            'Max this week (${p.weeklySmallSessions}S + ${p.weeklyBigSessions}B)',
            _fmt(r.freeMinutes + r.smallRewardMinutes * p.weeklySmallSessions + r.bigRewardMinutes * p.weeklyBigSessions),
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _EcoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _EcoRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: bold ? AppTypography.body.copyWith(fontWeight: FontWeight.w600) : AppTypography.body)),
          Text(value, style: bold ? AppTypography.monoStrong : AppTypography.mono),
        ],
      ),
    );
  }
}

// ── Lock action card ──────────────────────────────────────────────────────────

class _LockActionCard extends StatelessWidget {
  final BlockingViewModel bvm;
  final VoidCallback onStartWorkout;
  const _LockActionCard({required this.bvm, required this.onStartWorkout});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      color: AppColors.errorMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_clock, color: AppColors.error, size: 16),
              const SizedBox(width: 8),
              Text('Screen-Time Depleted', style: AppTypography.heading.copyWith(fontSize: 15, color: AppColors.error)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Complete a workout to earn more screen time.', style: AppTypography.body.copyWith(color: AppColors.error)),
          if (bvm.emergencyBreakActive) ...[
            const SizedBox(height: AppSpacing.md),
            _EmbeddedCountdown(bvm: bvm),
          ],
          const SizedBox(height: AppSpacing.base),
          AppButton.primary('Start Workout', onPressed: onStartWorkout, width: double.infinity, icon: Icons.fitness_center),
          const SizedBox(height: 8),
          if (!bvm.emergencyBreakActive)
            if (bvm.canRequestBreak)
              AppButton.ghost(
                'Take a break  ·  ${bvm.remainingBreakMinutes} min left today',
                onPressed: () => _openBreakPicker(context),
                width: double.infinity,
              )
            else
              Center(child: Text('No break time left today. Resets at midnight.', style: AppTypography.labelMuted, textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Future<void> _openBreakPicker(BuildContext context) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BreakPickerSheet(bvm: bvm),
    );
    if (minutes != null && minutes > 0) await bvm.requestEmergencyBreak(minutes);
  }
}

class _BreakPickerSheet extends StatefulWidget {
  final BlockingViewModel bvm;
  const _BreakPickerSheet({required this.bvm});

  @override
  State<_BreakPickerSheet> createState() => _BreakPickerSheetState();
}

class _BreakPickerSheetState extends State<_BreakPickerSheet> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.bvm.remainingBreakMinutes.clamp(1, 15);
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.bvm.remainingBreakMinutes;

    return Container(
      color: AppColors.paper,
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.base, AppSpacing.xl, MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 3, color: AppColors.paperBorder),
          const SizedBox(height: AppSpacing.lg),
          Text('Take a Break', style: AppTypography.title),
          const SizedBox(height: 4),
          Text('$max min remaining today', style: AppTypography.bodyMuted),
          const SizedBox(height: AppSpacing.xl),
          Text('$_selected', style: AppTypography.display),
          Text('minutes', style: AppTypography.bodyMuted),
          const SizedBox(height: AppSpacing.base),
          Slider(
            value: _selected.toDouble(),
            min: 1,
            max: max.toDouble(),
            divisions: max > 1 ? max - 1 : 1,
            onChanged: (v) => setState(() => _selected = v.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 min', style: AppTypography.labelMuted),
              Text('$max min', style: AppTypography.labelMuted),
            ],
          ),
          const SizedBox(height: 8),
          Text('Does not replenish your screen-time balance.', style: AppTypography.labelMuted, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          AppButton.primary('Use $_selected min', onPressed: () => Navigator.pop(context, _selected), width: double.infinity),
          const SizedBox(height: 8),
          AppButton.ghost('Cancel', onPressed: () => Navigator.pop(context, null), width: double.infinity),
        ],
      ),
    );
  }
}

class _EmbeddedCountdown extends StatelessWidget {
  final BlockingViewModel bvm;
  const _EmbeddedCountdown({required this.bvm});

  @override
  Widget build(BuildContext context) {
    final secs = bvm.emergencyBreakSecondsRemaining;
    final mins = secs ~/ 60;
    final s = secs % 60;
    final label = '${mins.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: AppColors.acid,
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 16, color: AppColors.ink),
          const SizedBox(width: 8),
          Text('Break ends in $label', style: AppTypography.monoStrong.copyWith(color: AppColors.ink)),
        ],
      ),
    );
  }
}

// ── Setup prompt ──────────────────────────────────────────────────────────────

class _SetupPrompt extends StatelessWidget {
  final VoidCallback onSetup;
  const _SetupPrompt({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.base),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.signal, width: 3)),
      ),
      child: AppCard(
        backgroundColor: AppColors.paperAlt,
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          children: [
            const Icon(Icons.tune_outlined, size: 32, color: AppColors.ink),
            const SizedBox(height: AppSpacing.sm),
            Text('Set up your screen time economy', style: AppTypography.heading.copyWith(fontSize: 15), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Tell us how many hours you use your phone daily and your weekly workout plan.', style: AppTypography.bodyMuted, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            AppButton.primary('Go to Settings', onPressed: onSetup, width: double.infinity),
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
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
