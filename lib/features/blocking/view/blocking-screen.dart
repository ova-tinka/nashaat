import 'package:flutter/material.dart';

import '../../../core/entities/blocking-rule-entity.dart';
import '../../../main.dart';
import '../../../core/entities/enums.dart';
import '../../../infra/blocking/blocking-platform-service.dart';
import '../../../infra/permissions/permission-service.dart';
import '../../../infra/repository-locator.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-divider.dart';
import '../../../shared/design/molecules/app-card.dart';
import '../../../shared/design/organisms/app-empty-state.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../coordinator/blocking-coordinator.dart';
import '../view-model/blocking-view-model.dart';

class BlockingScreen extends StatefulWidget {
  final String userId;

  const BlockingScreen({super.key, required this.userId});

  @override
  State<BlockingScreen> createState() => _BlockingScreenState();
}

class _BlockingScreenState extends State<BlockingScreen> {
  late final BlockingViewModel _vm;
  late final BlockingCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    final platform = BlockingPlatformService();
    _vm = BlockingViewModel(
      userId: widget.userId,
      blockingRepo: RepositoryLocator.instance.blocking,
      platform: platform,
      permissionService: PermissionService(platform),
      emergencyBreakRepo: RepositoryLocator.instance.emergencyBreak,
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
      listenable: _vm,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.paper,
          appBar: AppBar(
            backgroundColor: AppColors.paper,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            title: Text(
              'APP BLOCKING',
              style: AppTypography.sectionHeader.copyWith(fontSize: 13, letterSpacing: 2),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: AppDivider(),
            ),
          ),
          body: _vm.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.ink))
              : _buildBody(context),
          floatingActionButton: _vm.permissions.isFullyGranted
              ? FloatingActionButton.extended(
                  onPressed: _vm.isIos
                      ? () => _vm.openIosPicker()
                      : () => _coordinator.showAppPicker(context, _vm),
                  backgroundColor: AppColors.ink,
                  foregroundColor: AppColors.paper,
                  shape: const RoundedRectangleBorder(),
                  elevation: 0,
                  icon: const Icon(Icons.add),
                  label: Text('Add App', style: AppTypography.label.copyWith(color: AppColors.paper)),
                )
              : null,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: _vm.initialize,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          if (_vm.error != null)
            _ErrorBanner(message: _vm.error!, onDismiss: _vm.clearError),
          if (!_vm.permissions.isFullyGranted) ...[
            _PermissionsSection(vm: _vm),
            const SizedBox(height: AppSpacing.base),
          ],
          if (_vm.permissions.isFullyGranted) ...[
            _BlockingToggle(vm: _vm),
            const SizedBox(height: AppSpacing.base),
          ],
          _BlockedAppsList(vm: _vm, coordinator: _coordinator),
        ],
      ),
    );
  }
}

// ── Permission section ────────────────────────────────────────────────────────

class _PermissionsSection extends StatelessWidget {
  final BlockingViewModel vm;
  const _PermissionsSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    final missing = vm.permissions.missing;
    return AppCard.signal(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.ink, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text('Permissions Required', style: AppTypography.heading.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Nashaat needs the following permissions to block apps.',
            style: AppTypography.body,
          ),
          const SizedBox(height: AppSpacing.md),
          ...missing.map(
            (p) => _PermissionRow(permission: p, onGrant: () => vm.requestPermission(p)),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final MissingPermission permission;
  final VoidCallback onGrant;

  const _PermissionRow({required this.permission, required this.onGrant});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 6, height: 6, color: AppColors.ink),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(permission.label, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                Text(permission.description, style: AppTypography.labelMuted),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton.ghost('Grant', onPressed: onGrant),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base, vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Blocking Active', style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
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
            onChanged: vm.rules.isEmpty
                ? null
                : (on) => on ? vm.activateBlocking() : vm.deactivateBlocking(),
            activeThumbColor: AppColors.acid,
          ),
        ],
      ),
    );
  }
}

// ── Blocked apps list ─────────────────────────────────────────────────────────

class _BlockedAppsList extends StatelessWidget {
  final BlockingViewModel vm;
  final BlockingCoordinator coordinator;

  const _BlockedAppsList({required this.vm, required this.coordinator});

  @override
  Widget build(BuildContext context) {
    if (vm.rules.isEmpty) {
      return AppEmptyState(
        title: 'No apps blocked yet',
        body: 'Tap "Add App" to choose which apps to restrict when your balance runs out.',
        icon: Icons.block,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text(
            '${vm.rules.length} rule(s) active',
            style: AppTypography.labelMuted,
          ),
        ),
        ...vm.rules.map((rule) {
          if (rule.itemIdentifier.startsWith('ios_selection:')) {
            return _IosSelectionCard(rule: rule, vm: vm, coordinator: coordinator);
          }
          return _AppRuleCard(rule: rule, vm: vm);
        }),
      ],
    );
  }
}

class _IosSelectionCard extends StatelessWidget {
  final BlockingRuleEntity rule;
  final BlockingViewModel vm;
  final BlockingCoordinator coordinator;

  const _IosSelectionCard({
    required this.rule,
    required this.vm,
    required this.coordinator,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = rule.status == RuleStatus.active;
    final summary = vm.iosSummary;
    final subtitleText = summary != null && !summary.isEmpty
        ? summary.displayText
        : 'Tap Modify to see selected apps';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.paperBorder),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                color: AppColors.paperAlt,
                child: const Icon(Icons.shield_outlined, color: AppColors.ink, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('iOS Screen Time', style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                    Text(subtitleText, style: AppTypography.labelMuted),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                onChanged: (_) => vm.toggleRule(rule.id),
                activeThumbColor: AppColors.acid,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton.ghost(
                'Modify',
                icon: Icons.edit_outlined,
                onPressed: () => vm.openIosPicker(),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton.destructive(
                'Remove',
                icon: Icons.delete_outline,
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: const RoundedRectangleBorder(),
        title: Text('Remove Blocking', style: AppTypography.heading),
        content: Text(
          'Remove all blocked apps? This will turn off Screen Time blocking.',
          style: AppTypography.body,
        ),
        actions: [
          AppButton.ghost('Cancel', onPressed: () => Navigator.pop(context, false)),
          AppButton.destructive('Remove', onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (confirmed == true) {
      await vm.removeRule(rule.id);
    }
  }
}

class _AppRuleCard extends StatelessWidget {
  final BlockingRuleEntity rule;
  final BlockingViewModel vm;

  const _AppRuleCard({required this.rule, required this.vm});

  @override
  Widget build(BuildContext context) {
    final isActive = rule.status == RuleStatus.active;
    final appLabel = rule.itemIdentifier.split('.').last;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.paperBorder),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base, vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            color: AppColors.ink,
            alignment: Alignment.center,
            child: Text(
              appLabel.substring(0, 1).toUpperCase(),
              style: AppTypography.monoStrong.copyWith(color: AppColors.paper),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appLabel, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                Text(rule.itemIdentifier, style: AppTypography.labelMuted),
              ],
            ),
          ),
          Switch(
            value: isActive,
            onChanged: (_) => vm.toggleRule(rule.id),
            activeThumbColor: AppColors.acid,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: const RoundedRectangleBorder(),
        title: Text('Remove App', style: AppTypography.heading),
        content: Text(
          'Remove "${rule.itemIdentifier.split('.').last}" from your block list?',
          style: AppTypography.body,
        ),
        actions: [
          AppButton.ghost('Cancel', onPressed: () => Navigator.pop(context, false)),
          AppButton.destructive('Remove', onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (confirmed == true) {
      await vm.removeRule(rule.id);
    }
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
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: AppTypography.body.copyWith(color: AppColors.error)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, color: AppColors.error, size: 16),
          ),
        ],
      ),
    );
  }
}
