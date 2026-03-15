import 'package:flutter/material.dart';

import '../../../core/entities/blocking-rule-entity.dart';
import '../../../main.dart';
import '../../../core/entities/enums.dart';
import '../../../infra/blocking/blocking-platform-service.dart';
import '../../../infra/permissions/permission-service.dart';
import '../../../infra/supabase/blocking-repository-impl.dart';
import '../coordinator/blocking-coordinator.dart';
import '../view_model/blocking-view-model.dart';

/// Entry point for UC-08 Mobile App Blocking.
///
/// Usage: push this route and pass the authenticated [userId].
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
      blockingRepo: SupabaseBlockingRepository(),
      platform: platform,
      permissionService: PermissionService(platform),
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
          appBar: AppBar(title: const Text('App Blocking')),
          body: _vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(context),
          floatingActionButton: _vm.permissions.isFullyGranted
              ? FloatingActionButton.extended(
                  onPressed: () =>
                      _coordinator.showAppPicker(context, _vm),
                  icon: const Icon(Icons.add),
                  label: const Text('Add App'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _vm.initialize,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_vm.error != null) _ErrorBanner(message: _vm.error!, onDismiss: _vm.clearError),
          if (!_vm.permissions.isFullyGranted) ...[
            _PermissionsSection(vm: _vm),
            const SizedBox(height: 16),
          ],
          if (_vm.permissions.isFullyGranted) ...[
            _BlockingToggle(vm: _vm),
            const SizedBox(height: 16),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Permissions Required',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Nashaat needs the following permissions to block apps.',
            ),
            const SizedBox(height: 12),
            ...missing.map(
              (p) => _PermissionRow(permission: p, onGrant: () => vm.requestPermission(p)),
            ),
          ],
        ),
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
          const Icon(Icons.circle, size: 8),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(permission.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  permission.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onGrant, child: const Text('Grant')),
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
    return Card(
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
            : (on) =>
                on ? vm.activateBlocking() : vm.deactivateBlocking(),
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
      return const _EmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${vm.rules.length} app(s) managed',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        ...vm.rules.map((rule) => _AppRuleCard(rule: rule, vm: vm)),
      ],
    );
  }
}

class _AppRuleCard extends StatelessWidget {
  final BlockingRuleEntity rule;
  final BlockingViewModel vm;

  const _AppRuleCard({required this.rule, required this.vm});

  @override
  Widget build(BuildContext context) {
    final isActive = rule.status == RuleStatus.active;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            rule.itemIdentifier.split('.').last.substring(0, 1).toUpperCase(),
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
              color: Theme.of(context).colorScheme.error,
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove App'),
        content: Text(
            'Remove "${rule.itemIdentifier.split('.').last}" from your block list?'),
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
    if (confirmed == true) {
      await vm.removeRule(rule.id);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.block,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No apps blocked yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap "Add App" to choose which apps\nto restrict when your balance runs out.',
              textAlign: TextAlign.center,
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
            child: Text(
              message,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer),
            ),
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
