import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app-router.dart';
import '../../../core/entities/blocking-rule-entity.dart';
import '../../../core/entities/enums.dart';
import '../../../infra/blocking/blocking-platform-service.dart';
import '../../../infra/repository-locator.dart';
import '../../../main.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-nav-icon.dart';
import '../../../shared/design/atoms/app-status-pill.dart';
import '../../../shared/design/atoms/app-text.dart';
import '../../../shared/design/molecules/app-balance-ring.dart';
import '../../../shared/design/molecules/app-card.dart';
import '../../../shared/design/organisms/app-dialog.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-radii.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../settings/view/settings-screen.dart';
import '../coordinator/blocking-coordinator.dart';
import 'break-picker-sheet.dart';
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
  bool _exhaustedShown = false;

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
    _vm.addListener(_checkExhausted);
    _vm.initialize();
  }

  void _checkExhausted() {
    if (!mounted || _exhaustedShown) return;
    if (_vm.balanceMinutes == 0 && _vm.blockingVm.isBlockingActive) {
      _exhaustedShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context)
            .pushNamed(
              AppRouter.timeExhausted,
              arguments: {
                'nextWorkoutMinutes': _vm.rewards.smallRewardMinutes,
                'lockedAppCount': _vm.blockingVm.activeRules.length,
                'blockingVm': _vm.blockingVm,
              },
            )
            .then((_) => _exhaustedShown = false);
      });
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_checkExhausted);
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_vm, _vm.blockingVm]),
      builder: (context, _) {
        final bvm = _vm.blockingVm;
        final palette = context.nashaatPalette;
        return Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: palette.accent,
              onRefresh: () async {
                await _vm.refresh();
                await bvm.initialize();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  120,
                ),
                children: [
                  _FocusHeader(isOpen: _isAppsOpen(_vm, bvm)),
                  const SizedBox(height: AppSpacing.lg),
                  if (_vm.isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 120),
                      child: Center(
                        child: CircularProgressIndicator(color: palette.accent),
                      ),
                    )
                  else ...[
                    if (_vm.error != null)
                      _FocusError(
                        message: _vm.error!,
                        onDismiss: _vm.clearError,
                      ),
                    if (bvm.error != null)
                      _FocusError(
                        message: bvm.error!,
                        onDismiss: bvm.clearError,
                      ),
                    _BalanceSection(vm: _vm),
                    const SizedBox(height: AppSpacing.lg),
                    if (_vm.balanceMinutes == 0 && bvm.isBlockingActive) ...[
                      _DepletedCard(
                        bvm: bvm,
                        onStartWorkout: appCoordinator.showDashboard,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (_vm.isConfigured)
                      _FocusEconomyCard(vm: _vm)
                    else
                      _SetupPrompt(
                        onSetup: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    _BlockingSection(
                      vm: bvm,
                      onAddApp: () => _coordinator.showAppPicker(context, bvm),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isAppsOpen(FocusViewModel vm, BlockingViewModel bvm) {
    return vm.appsUnblocked ||
        (!vm.hasBlockedApps && vm.balanceMinutes > 0) ||
        !bvm.isBlockingActive;
  }
}

class _FocusHeader extends StatelessWidget {
  final bool isOpen;

  const _FocusHeader({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: AppText.hero('Focus')),
        AppStatusPill(
          label: isOpen ? 'Apps open' : 'Apps locked',
          tone: isOpen ? AppStatusTone.accent : AppStatusTone.locked,
          showDot: true,
        ),
      ],
    );
  }
}

class _BalanceSection extends StatelessWidget {
  final FocusViewModel vm;

  const _BalanceSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    final profile = vm.profile;
    final rewards = vm.rewards;
    final maxMinutes = profile == null
        ? 0
        : rewards.freeMinutes +
              rewards.smallRewardMinutes * profile.weeklySmallSessions +
              rewards.bigRewardMinutes * profile.weeklyBigSessions;
    final progress = maxMinutes == 0
        ? 0.0
        : (vm.balanceMinutes / maxMinutes).clamp(0.0, 1.0);

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = (constraints.maxWidth * 0.72)
                .clamp(220.0, 270.0)
                .toDouble();
            return AppBalanceRing(
              progress: progress,
              size: size,
              balanceLabel: _formatMinutes(vm.balanceMinutes),
              caption: 'Balance',
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppText.bodyMuted(
          'Earn more by finishing workouts',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FocusEconomyCard extends StatelessWidget {
  final FocusViewModel vm;

  const _FocusEconomyCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final profile = vm.profile!;
    final rewards = vm.rewards;
    final palette = context.nashaatPalette;
    final maximum =
        rewards.freeMinutes +
        rewards.smallRewardMinutes * profile.weeklySmallSessions +
        rewards.bigRewardMinutes * profile.weeklyBigSessions;

    return AppCard.standard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.section("THIS WEEK'S NUMBERS"),
          const SizedBox(height: AppSpacing.md),
          _EconomyRow('Daily phone usage', '${profile.dailyPhoneHours}h'),
          _EconomyRow(
            'Free every week (20%)',
            _formatMinutes(rewards.freeMinutes),
          ),
          _EconomyRow(
            'Small workout',
            '+${_formatMinutes(rewards.smallRewardMinutes)}',
            valueColor: palette.accentText,
          ),
          _EconomyRow(
            'Big workout',
            '+${_formatMinutes(rewards.bigRewardMinutes)}',
            valueColor: palette.accentText,
          ),
          _EconomyRow(
            'Most you can earn (${profile.weeklySmallSessions} small + '
            '${profile.weeklyBigSessions} big)',
            _formatMinutes(maximum),
            valueColor: palette.textPrimary,
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _EconomyRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool strong;

  const _EconomyRow(
    this.label,
    this.value, {
    this.valueColor,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: AppText.body(label)),
          const SizedBox(width: AppSpacing.md),
          Text(
            value,
            textAlign: TextAlign.end,
            style:
                (strong
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.titleSmall)
                    ?.copyWith(
                      color: valueColor ?? palette.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
          ),
        ],
      ),
    );
  }
}

class _BlockingSection extends StatelessWidget {
  final BlockingViewModel vm;
  final VoidCallback onAddApp;

  const _BlockingSection({required this.vm, required this.onAddApp});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText.section('BLOCKED APPS'),
        const SizedBox(height: AppSpacing.md),
        if (!vm.permissions.isFullyGranted)
          _PermissionsCard(vm: vm)
        else ...[
          _BlockingToggle(vm: vm),
          const SizedBox(height: AppSpacing.md),
          _BlockedAppsList(vm: vm, onAddApp: onAddApp),
        ],
      ],
    );
  }
}

class _PermissionsCard extends StatelessWidget {
  final BlockingViewModel vm;

  const _PermissionsCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return AppCard.attention(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: palette.dangerText, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppText.heading(
                  'Permissions required',
                  color: palette.dangerText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppText.bodyMuted('Nashaat needs these permissions to block apps.'),
          const SizedBox(height: AppSpacing.md),
          ...vm.permissions.missing.map(
            (permission) => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText.body(permission.label),
                        AppText.bodyMuted(permission.description),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton.secondary(
                    'Grant',
                    width: 88,
                    onPressed: () => vm.requestPermission(permission),
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

class _BlockingToggle extends StatelessWidget {
  final BlockingViewModel vm;

  const _BlockingToggle({required this.vm});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return AppCard.standard(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.body('Blocking active'),
                AppText.bodyMuted(
                  vm.isBlockingActive
                      ? '${vm.activeRules.length} app(s) currently blocked.'
                      : 'Toggle on to start blocking selected apps.',
                ),
              ],
            ),
          ),
          Switch(
            value: vm.isBlockingActive,
            activeThumbColor: palette.accent,
            activeTrackColor: palette.accent.withValues(alpha: 0.28),
            onChanged: vm.rules.isEmpty
                ? null
                : (on) => on ? vm.activateBlocking() : vm.deactivateBlocking(),
          ),
        ],
      ),
    );
  }
}

class _BlockedAppsList extends StatelessWidget {
  final BlockingViewModel vm;
  final VoidCallback onAddApp;

  const _BlockedAppsList({required this.vm, required this.onAddApp});

  @override
  Widget build(BuildContext context) {
    final hasIosSelection = vm.rules.any(
      (rule) => rule.itemIdentifier.startsWith('ios_selection:'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (vm.rules.isEmpty)
          AppCard.flat(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: AppText.bodyMuted(
              'No apps selected yet.',
              textAlign: TextAlign.center,
            ),
          )
        else
          ...vm.rules.map(
            (rule) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _AppRuleCard(rule: rule, vm: vm, onModify: onAddApp),
            ),
          ),
        if (!vm.isIos || !hasIosSelection)
          AppButton.secondary(
            'Add app',
            onPressed: onAddApp,
            width: double.infinity,
            icon: Icons.add,
          ),
      ],
    );
  }
}

class _AppRuleCard extends StatelessWidget {
  final BlockingRuleEntity rule;
  final BlockingViewModel vm;
  final VoidCallback? onModify;

  const _AppRuleCard({
    required this.rule,
    required this.vm,
    required this.onModify,
  });

  bool get _isIosSelection => rule.itemIdentifier.startsWith('ios_selection:');

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    if (_isIosSelection) {
      final count = rule.itemIdentifier.split(':').last;
      return _RuleSurface(
        icon: const AppNavIcon(glyph: AppNavGlyph.fanar, size: 24),
        title: 'Screen Time selection',
        subtitle: '$count item(s) via iOS Screen Time',
        trailing: TextButton(
          onPressed: onModify,
          child: Text(
            'Modify',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: palette.accentText),
          ),
        ),
        onDelete: () => _confirmDelete(context),
      );
    }

    final shortName = rule.itemIdentifier.split('.').last;
    final isActive = rule.status == RuleStatus.active;
    return _RuleSurface(
      icon: Text(
        shortName.isEmpty ? '?' : shortName.substring(0, 1).toUpperCase(),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: palette.calmText,
          fontWeight: FontWeight.w700,
        ),
      ),
      title: shortName,
      subtitle: rule.itemIdentifier,
      trailing: Switch(
        value: isActive,
        activeThumbColor: palette.accent,
        activeTrackColor: palette.accent.withValues(alpha: 0.28),
        onChanged: (_) => vm.toggleRule(rule.id),
      ),
      onDelete: () => _confirmDelete(context),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final label = _isIosSelection
        ? 'Screen Time selection'
        : rule.itemIdentifier.split('.').last;
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: AppText.heading('Remove'),
      content: AppText.body('Remove "$label" from your block list?'),
      actions: [
        AppButton.ghost(
          'Cancel',
          onPressed: () => Navigator.pop(context, false),
        ),
        AppButton.destructive(
          'Remove',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (confirmed == true) await vm.removeRule(rule.id);
  }
}

class _RuleSurface extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onDelete;

  const _RuleSurface({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return AppCard.standard(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.raised,
              borderRadius: AppRadii.control,
            ),
            child: icon,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.body(title),
                AppText.mono(
                  subtitle,
                  color: palette.textMuted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          trailing,
          IconButton(
            tooltip: 'Remove',
            onPressed: onDelete,
            icon: Icon(Icons.close, size: 18, color: palette.dangerText),
          ),
        ],
      ),
    );
  }
}

class _DepletedCard extends StatelessWidget {
  final BlockingViewModel bvm;
  final VoidCallback onStartWorkout;

  const _DepletedCard({required this.bvm, required this.onStartWorkout});

  @override
  Widget build(BuildContext context) {
    return AppCard.attention(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                color: context.nashaatPalette.lockedText,
              ),
              const SizedBox(width: AppSpacing.sm),
              AppText.heading('Screen-time depleted'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppText.bodyMuted('Complete a workout to earn more screen time.'),
          if (bvm.emergencyBreakActive) ...[
            const SizedBox(height: AppSpacing.md),
            _EmbeddedCountdown(bvm: bvm),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton.primary(
            'Start a workout',
            onPressed: onStartWorkout,
            width: double.infinity,
          ),
          if (!bvm.emergencyBreakActive) ...[
            const SizedBox(height: AppSpacing.sm),
            if (bvm.canRequestBreak)
              AppButton.ghost(
                'Take a break · ${bvm.remainingBreakMinutes} min left',
                onPressed: () => _openBreakPicker(context),
                width: double.infinity,
              )
            else
              AppText.bodyMuted(
                'No break time left today. Resets at midnight.',
                textAlign: TextAlign.center,
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _openBreakPicker(BuildContext context) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlockingBreakPickerSheet(bvm: bvm),
    );
    if (minutes != null && minutes > 0) {
      await bvm.requestEmergencyBreak(minutes);
    }
  }
}

class _EmbeddedCountdown extends StatelessWidget {
  final BlockingViewModel bvm;

  const _EmbeddedCountdown({required this.bvm});

  @override
  Widget build(BuildContext context) {
    final seconds = bvm.emergencyBreakSecondsRemaining;
    final label =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}'
        ':${(seconds % 60).toString().padLeft(2, '0')}';
    return AppStatusPill(
      label: 'Break ends in $label',
      tone: AppStatusTone.calm,
      showDot: true,
    );
  }
}

class _SetupPrompt extends StatelessWidget {
  final VoidCallback onSetup;

  const _SetupPrompt({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return AppCard.standard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          AppNavIcon(glyph: AppNavGlyph.fanar, selected: true, size: 40),
          const SizedBox(height: AppSpacing.md),
          AppText.heading('Set up your screen-time economy'),
          const SizedBox(height: AppSpacing.xs),
          AppText.bodyMuted(
            'Tell us how many hours you use your phone daily and your weekly workout plan.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton.primary(
            'Go to Profile',
            onPressed: onSetup,
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}

class _FocusError extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _FocusError({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard.attention(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: palette.dangerText),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: AppText.body(message)),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: Icon(Icons.close, color: palette.dangerText),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '${remainder}m';
  return '${hours}h ${remainder.toString().padLeft(2, '0')}m';
}
