import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/entities/leaderboard-entity.dart';
import '../../../infra/repository-locator.dart';
import '../view-model/leaderboard-view-model.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final LeaderboardViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = LeaderboardViewModel(
      leaderboardRepo: RepositoryLocator.instance.leaderboard,
      profileRepo: RepositoryLocator.instance.profile,
    );
    _vm.load();
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
          appBar: AppBar(
            title: const Text('Leaderboards'),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Create or join',
                onPressed: () => _showCreateJoinSheet(context),
              ),
            ],
          ),
          body: _buildBody(context),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_vm.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_vm.error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                _vm.clearError();
                _vm.load();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_vm.leaderboards.isEmpty) {
      return _EmptyLeaderboards(
        onCreateTap: () => _showCreateJoinSheet(context),
      );
    }

    return RefreshIndicator(
      onRefresh: _vm.load,
      child: Column(
        children: [
          // Leaderboard selector
          if (_vm.leaderboards.length > 1)
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: _vm.leaderboards.length,
                itemBuilder: (context, i) {
                  final lb = _vm.leaderboards[i];
                  final selected = lb.id == _vm.selectedLeaderboard?.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(lb.name),
                      selected: selected,
                      onSelected: (_) => _vm.selectLeaderboard(lb),
                    ),
                  );
                },
              ),
            ),

          // Selected leaderboard header
          if (_vm.selectedLeaderboard != null)
            _LeaderboardHeader(
              vm: _vm,
              leaderboard: _vm.selectedLeaderboard!,
            ),

          // Rankings
          Expanded(
            child: _vm.isLoadingRankings
                ? const Center(child: CircularProgressIndicator())
                : _vm.rankings.isEmpty
                    ? const Center(
                        child: Text('No members yet. Share your invite code!'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        itemCount: _vm.rankings.length,
                        itemBuilder: (context, i) => _RankingTile(
                          entry: _vm.rankings[i],
                          isCurrentUser:
                              _vm.rankings[i].userId == _vm.currentUserId,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateJoinSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateJoinSheet(vm: _vm),
    );
  }
}

// ── Leaderboard header ────────────────────────────────────────────────────────

class _LeaderboardHeader extends StatelessWidget {
  final LeaderboardViewModel vm;
  final LeaderboardEntity leaderboard;

  const _LeaderboardHeader({required this.vm, required this.leaderboard});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final myRank = vm.myRank;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leaderboard.name,
                  style: tt.titleMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (myRank > 0)
                  Text(
                    'Your rank: #$myRank',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onPrimaryContainer),
                  ),
              ],
            ),
          ),
          _InviteButton(inviteCode: leaderboard.inviteCode),
        ],
      ),
    );
  }
}

class _InviteButton extends StatelessWidget {
  final String inviteCode;
  const _InviteButton({required this.inviteCode});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.onPrimaryContainer,
        side: BorderSide(color: cs.onPrimaryContainer.withOpacity(0.5)),
      ),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: inviteCode));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invite code copied: $inviteCode'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      icon: const Icon(Icons.copy, size: 16),
      label: Text(inviteCode, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ── Ranking tile ──────────────────────────────────────────────────────────────

class _RankingTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isCurrentUser;

  const _RankingTile({required this.entry, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final rank = entry.rank;

    final (medalIcon, medalColor) = switch (rank) {
      1 => (Icons.emoji_events, const Color(0xFFFFD700)),
      2 => (Icons.emoji_events, const Color(0xFFC0C0C0)),
      3 => (Icons.emoji_events, const Color(0xFFCD7F32)),
      _ => (Icons.person, cs.onSurfaceVariant),
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isCurrentUser ? cs.secondaryContainer : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: rank <= 3
                  ? Icon(medalIcon, color: medalColor, size: 24)
                  : Text(
                      '#$rank',
                      style: tt.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        entry.displayName,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isCurrentUser
                              ? cs.onSecondaryContainer
                              : null,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: cs.secondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'You',
                            style: tt.labelSmall?.copyWith(
                                color: cs.onSecondary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (entry.streakCount > 0)
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department,
                            size: 12, color: Colors.orange),
                        const SizedBox(width: 2),
                        Text(
                          '${entry.streakCount}d streak',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.weeklyScore}',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isCurrentUser ? cs.onSecondaryContainer : null,
                  ),
                ),
                Text(
                  'pts',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create / Join sheet ───────────────────────────────────────────────────────

class _CreateJoinSheet extends StatefulWidget {
  final LeaderboardViewModel vm;
  const _CreateJoinSheet({required this.vm});

  @override
  State<_CreateJoinSheet> createState() => _CreateJoinSheetState();
}

class _CreateJoinSheetState extends State<_CreateJoinSheet> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _creating = false;
  bool _joining = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Leaderboard',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // Create
          Text('Create New', style: tt.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Leaderboard name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _creating
                ? null
                : () {
                    final name = _nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    setState(() => _creating = true);
                    widget.vm.createLeaderboard(name).then((_) {
                      if (mounted) Navigator.pop(context);
                    });
                  },
            child: _creating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or'),
                ),
                Expanded(child: Divider()),
              ],
            ),
          ),

          // Join
          Text('Join with Invite Code', style: tt.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _codeCtrl,
            decoration: const InputDecoration(
              labelText: 'Invite code',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _joining
                ? null
                : () {
                    final code = _codeCtrl.text.trim().toUpperCase();
                    if (code.isEmpty) return;
                    setState(() => _joining = true);
                    widget.vm.joinByInviteCode(code).then((_) {
                      if (mounted) Navigator.pop(context);
                    });
                  },
            child: _joining
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class _EmptyLeaderboards extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyLeaderboards({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.leaderboard_outlined, size: 72, color: cs.outlineVariant),
            const SizedBox(height: 20),
            Text(
              'No leaderboards yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Compete with friends and track weekly discipline scores.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Create Leaderboard'),
            ),
          ],
        ),
      ),
    );
  }
}
