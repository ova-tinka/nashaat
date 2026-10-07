import 'dart:async';

import 'package:flutter/material.dart';

import '../../../infra/repository-locator.dart';
import '../../../shared/design/organisms/app-empty-state.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../view-model/friends-view-model.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late final FriendsViewModel _vm;
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _vm = FriendsViewModel(
      friendshipRepo: RepositoryLocator.instance.friendship,
      profileRepo: RepositoryLocator.instance.profile,
    )..load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _vm.search(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('FRIENDS')),
        body: _vm.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_vm.error != null &&
        _vm.friends.isEmpty &&
        _vm.incomingRequests.isEmpty) {
      return AppEmptyState(
        title: 'Could not load friends',
        body: _vm.error!,
        primaryLabel: 'Retry',
        onPrimary: _vm.load,
        icon: Icons.error_outline,
      );
    }
    return RefreshIndicator(
      onRefresh: _vm.load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          Text('YOUR CIRCLE', style: AppTypography.sectionHeader),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Find athletes by their name or username. Only public profile details are shown.',
            style: AppTypography.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search athletes',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        _vm.search('');
                        setState(() {});
                      },
                    ),
            ),
          ),
          if (_searchController.text.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _SectionTitle('SEARCH RESULTS'),
            if (_vm.isSearching)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_vm.searchResults.isEmpty)
              const _Hint(
                'No athletes found. Try a different name or username.',
              )
            else
              ..._vm.searchResults.map(
                (person) => _FriendTile(
                  person: person,
                  busy: _vm.isMutating,
                  onSend: () => _vm.sendRequest(person),
                  onAccept: () => _vm.acceptRequest(person),
                  onDecline: () => _vm.declineRequest(person),
                  onRemove: () => _confirmRemove(context, person),
                ),
              ),
          ] else ...[
            if (_vm.incomingRequests.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _SectionTitle('REQUESTS (${_vm.incomingRequests.length})'),
              ..._vm.incomingRequests.map(
                (person) => _FriendTile(
                  person: person,
                  busy: _vm.isMutating,
                  onAccept: () => _vm.acceptRequest(person),
                  onDecline: () => _vm.declineRequest(person),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _SectionTitle('FRIENDS (${_vm.friends.length})'),
            if (_vm.friends.isEmpty)
              const _Hint('Search for people to start your circle.')
            else
              ..._vm.friends.map(
                (person) => _FriendTile(
                  person: person,
                  busy: _vm.isMutating,
                  onRemove: () => _confirmRemove(context, person),
                ),
              ),
            if (_vm.sentRequests.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _SectionTitle('SENT REQUESTS'),
              ..._vm.sentRequests.map(
                (person) => _FriendTile(person: person, busy: _vm.isMutating),
              ),
            ],
          ],
          if (_vm.error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _vm.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    FriendProfile person,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text(
          '${person.displayName} will no longer be in your circle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _vm.removeFriend(person);
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: AppTypography.sectionHeader),
  );
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Text(text, style: AppTypography.bodyMuted),
  );
}

class _FriendTile extends StatelessWidget {
  final FriendProfile person;
  final bool busy;
  final VoidCallback? onSend;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onRemove;
  const _FriendTile({
    required this.person,
    required this.busy,
    this.onSend,
    this.onAccept,
    this.onDecline,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.nashaatPalette;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: palette.raised,
            foregroundColor: palette.textPrimary,
            child: Text(person.displayName.characters.first.toUpperCase()),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (person.profile.streakCount > 0)
                  Text(
                    '${person.profile.streakCount}-day streak',
                    style: AppTypography.labelMuted,
                  ),
                if (person.relationship == FriendRelationship.outgoingPending)
                  Text('Request sent', style: AppTypography.labelMuted),
              ],
            ),
          ),
          _ActionButtons(
            relationship: person.relationship,
            busy: busy,
            onSend: onSend,
            onAccept: onAccept,
            onDecline: onDecline,
            onRemove: onRemove,
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final FriendRelationship relationship;
  final bool busy;
  final VoidCallback? onSend;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onRemove;
  const _ActionButtons({
    required this.relationship,
    required this.busy,
    this.onSend,
    this.onAccept,
    this.onDecline,
    this.onRemove,
  });
  @override
  Widget build(BuildContext context) => switch (relationship) {
    FriendRelationship.none => FilledButton(
      onPressed: busy ? null : onSend,
      child: const Text('Add'),
    ),
    FriendRelationship.incomingPending => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Accept',
          onPressed: busy ? null : onAccept,
          icon: const Icon(Icons.check),
        ),
        IconButton(
          tooltip: 'Decline',
          onPressed: busy ? null : onDecline,
          icon: const Icon(Icons.close),
        ),
      ],
    ),
    FriendRelationship.friends => IconButton(
      tooltip: 'Remove friend',
      onPressed: busy ? null : onRemove,
      icon: const Icon(Icons.person_remove_outlined),
    ),
    FriendRelationship.outgoingPending => const Icon(Icons.schedule),
  };
}
