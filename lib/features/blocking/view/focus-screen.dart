import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/blocking-rule-entity.dart';
import '../../../core/entities/enums.dart';
import '../../../infra/blocking/blocking-platform-service.dart';
import '../../../infra/repository-locator.dart';
import '../../../main.dart';
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
          appBar: AppBar(
            title: const Text('Focus'),
            centerTitle: false,
          ),
          body: _vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    await _vm.refresh();
                    await bvm.initialize();
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_vm.error != null)
                        _ErrorBanner(
                          message: _vm.error!,
                          onDismiss: _vm.clearError,
                        ),
                      if (bvm.error != null)
                        _ErrorBanner(
                          message: bvm.error!,
                          onDismiss: bvm.clearError,
                        ),

                      // ── Screen time status ──────────────────────────────
                      _StatusCard(vm: _vm),
                      const SizedBox(height: 16),

                      // ── Lock action card (balance depleted) ─────────────
                      if (_vm.balanceMinutes == 0 &&
                          bvm.isBlockingActive) ...[
                        _LockActionCard(
                          bvm: bvm,
                          onStartWorkout: () =>
                              appCoordinator.showDashboard(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Rewards economy ─────────────────────────────────
                      if (_vm.isConfigured) ...[
                        _RewardsPreview(vm: _vm),
                        const SizedBox(height: 16),
                      ],
                      if (!_vm.isConfigured)
                        _SetupPrompt(onSetup: () => _openSettings(context)),

                      // ── Blocking management ─────────────────────────────
                      _SectionHeader(title: 'Blocked Apps'),
                      const SizedBox(height: 8),

                      if (!bvm.permissions.isFullyGranted)
                        _PermissionsSection(vm: bvm)
                      else ...[
                        _BlockingToggle(vm: bvm),
                        const SizedBox(height: 12),
                        _BlockedAppsList(
                          vm: bvm,
                          onAddApp: () => _coordinator.showAppPicker(context, bvm),
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        );
      },
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

// ── Status card ───────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final FocusViewModel vm;
  const _StatusCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final balance = vm.balanceMinutes;
    final hours = balance ~/ 60;
    final mins = balance % 60;
    final balanceLabel = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    final unblocked = vm.appsUnblocked;
    final cardColor = unblocked ? cs.primaryContainer : cs.errorContainer;
    final onCardColor = unblocked ? cs.onPrimaryContainer : cs.onErrorContainer;

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  unblocked ? Icons.lock_open_outlined : Icons.lock_outlined,
                  color: onCardColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  unblocked ? 'Apps unblocked' : 'Apps blocked',
                  style: tt.titleMedium?.copyWith(
                    color: onCardColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              balance > 0 ? balanceLabel : 'No balance',
              style: tt.displaySmall?.copyWith(
                color: onCardColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              balance > 0
                  ? unblocked
                      ? 'Draining while blocked apps are in use'
                      : 'Earn more by completing workouts'
                  : 'Complete a workout to earn screen time',
              style: tt.bodyMedium
                  ?.copyWith(color: onCardColor.withValues(alpha: 0.8)),
            ),
          ],
        ),
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
    final cs = Theme.of(context).colorScheme;
    final missing = vm.permissions.missing;
    return Card(
      elevation: 0,
      color: cs.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: cs.onErrorContainer),
                const SizedBox(width: 8),
                Text(
                  'Permissions Required',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: cs.onErrorContainer),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Nashaat needs the following permissions to block apps.',
              style: TextStyle(color: cs.onErrorContainer),
            ),
            const SizedBox(height: 12),
            ...missing.map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.label,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onErrorContainer)),
                          Text(p.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.onErrorContainer)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.onErrorContainer,
                        side: BorderSide(color: cs.onErrorContainer),
                      ),
                      onPressed: () => vm.requestPermission(p),
                      child: const Text('Grant'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SwitchListTile(
        title: const Text('Blocking Active'),
        subtitle: Text(
          vm.isBlockingActive
              ? '${vm.activeRules.length} app(s) are currently blocked.'
              : 'Toggle on to start blocking selected apps.',
        ),
        value: vm.isBlockingActive,
        onChanged: vm.rules.isEmpty
            ? null
            : (on) => on ? vm.activateBlocking() : vm.deactivateBlocking(),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          _EmptyApps(onAdd: onAddApp)
        else ...[
          ...vm.rules.map(
            (rule) => _AppRuleCard(rule: rule, vm: vm, onModify: onAddApp),
          ),
          const SizedBox(height: 8),
        ],
        if (!vm.isIos || !vm.rules.any((r) => r.itemIdentifier.startsWith('ios_selection:')))
          FilledButton.icon(
            onPressed: onAddApp,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add App'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
          ),
      ],
    );
  }
}

class _AppRuleCard extends StatelessWidget {
  final BlockingRuleEntity rule;
  final BlockingViewModel vm;
  final VoidCallback? onModify;

  const _AppRuleCard({required this.rule, required this.vm, this.onModify});

  bool get _isIosSelection =>
      rule.itemIdentifier.startsWith('ios_selection:');

  @override
  Widget build(BuildContext context) {
    if (_isIosSelection) return _buildIosCard(context);
    final cs = Theme.of(context).colorScheme;
    final isActive = rule.status == RuleStatus.active;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Text(
            rule.itemIdentifier.split('.').last.substring(0, 1).toUpperCase(),
            style: TextStyle(color: cs.onPrimaryContainer),
          ),
        ),
        title: Text(rule.itemIdentifier.split('.').last),
        subtitle: Text(
          rule.itemIdentifier,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: isActive,
              onChanged: (_) => vm.toggleRule(rule.id),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: cs.error,
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIosCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = rule.itemIdentifier.split(':').last;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(Icons.phone_iphone,
              color: cs.onPrimaryContainer, size: 18),
        ),
        title: const Text('Screen Time selection'),
        subtitle: Text('$count item(s) selected via iOS Screen Time'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: onModify,
              child: const Text('Modify'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: cs.error,
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final label = _isIosSelection
        ? 'Screen Time selection'
        : rule.itemIdentifier.split('.').last;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove'),
        content: Text('Remove "$label" from your block list?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed == true) await vm.removeRule(rule.id);
  }
}

class _EmptyApps extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyApps({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No apps in your block list yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rewards preview ───────────────────────────────────────────────────────────

class _RewardsPreview extends StatelessWidget {
  final FocusViewModel vm;
  const _RewardsPreview({required this.vm});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final r = vm.rewards;
    final p = vm.profile!;

    String fmt(int minutes) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    }

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This Week\'s Economy',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _RewardRow(
                icon: Icons.calendar_today_outlined,
                label: 'Daily phone usage',
                value: '${p.dailyPhoneHours}h'),
            _RewardRow(
                icon: Icons.card_giftcard_outlined,
                label: 'Free baseline (20%)',
                value: fmt(r.freeMinutes)),
            const Divider(height: 20),
            _RewardRow(
                icon: Icons.fitness_center,
                label: 'Small session reward',
                value: fmt(r.smallRewardMinutes)),
            _RewardRow(
                icon: Icons.local_fire_department,
                label: 'Big session reward',
                value: fmt(r.bigRewardMinutes)),
            const Divider(height: 20),
            _RewardRow(
              icon: Icons.check_circle_outline,
              label:
                  'Max this week (${p.weeklySmallSessions}S + ${p.weeklyBigSessions}B)',
              value: fmt(
                r.freeMinutes +
                    r.smallRewardMinutes * p.weeklySmallSessions +
                    r.bigRewardMinutes * p.weeklyBigSessions,
              ),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool bold;

  const _RewardRow({
    required this.icon,
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: bold
                  ? tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
                  : tt.bodyMedium,
            ),
          ),
          Text(
            value,
            style: tt.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold ? cs.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lock action card ──────────────────────────────────────────────────────────

class _LockActionCard extends StatelessWidget {
  final BlockingViewModel bvm;
  final VoidCallback onStartWorkout;

  const _LockActionCard({
    required this.bvm,
    required this.onStartWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: cs.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_clock, color: cs.onErrorContainer),
                const SizedBox(width: 8),
                Text(
                  'Screen-Time Depleted',
                  style: tt.titleMedium?.copyWith(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Complete a workout to earn more screen time.',
              style: tt.bodyMedium
                  ?.copyWith(color: cs.onErrorContainer.withValues(alpha: 0.8)),
            ),
            if (bvm.emergencyBreakActive) ...[
              const SizedBox(height: 12),
              _EmbeddedCountdown(bvm: bvm),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onStartWorkout,
              icon: const Icon(Icons.fitness_center),
              label: const Text('Start Workout'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            const SizedBox(height: 8),
            if (!bvm.emergencyBreakActive)
              if (bvm.canRequestBreak)
                TextButton(
                  onPressed: () => _openBreakPicker(context),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onErrorContainer,
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  child: Text(
                    'Take a break  ·  ${bvm.remainingBreakMinutes} min left today',
                  ),
                )
              else
                Text(
                  'No break time left today. Resets at midnight.',
                  style: tt.bodySmall?.copyWith(
                      color: cs.onErrorContainer.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center,
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBreakPicker(BuildContext context) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BreakPickerSheet(bvm: bvm),
    );
    if (minutes != null && minutes > 0) {
      await bvm.requestEmergencyBreak(minutes);
    }
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final max = widget.bvm.remainingBreakMinutes;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text('Take a Break',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('$max min remaining today',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 32),
          Text(
            '$_selected',
            style: tt.displayLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
          Text('minutes',
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
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
              Text('1 min',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              Text('$max min',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Does not replenish your screen-time balance.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context, _selected),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text('Use $_selected min'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
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
    final label =
        '${mins.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 18, color: cs.onPrimaryContainer),
          const SizedBox(width: 8),
          Text(
            'Break ends in $label',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
          ),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: cs.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.tune_outlined, size: 48, color: cs.onSecondaryContainer),
            const SizedBox(height: 12),
            Text(
              'Set up your screen time economy',
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSecondaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us how many hours you use your phone daily and your weekly workout plan.',
              style: tt.bodyMedium
                  ?.copyWith(color: cs.onSecondaryContainer.withValues(alpha: 0.8)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.onSecondaryContainer,
                foregroundColor: cs.secondaryContainer,
              ),
              onPressed: onSetup,
              child: const Text('Go to Settings'),
            ),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer)),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            color: Theme.of(context).colorScheme.onErrorContainer,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
