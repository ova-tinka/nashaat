import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/entities/leaderboard-entity.dart';
import '../../../infra/repository-locator.dart';
import '../../../shared/design/atoms/app-badge.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-divider.dart';
import '../../../shared/design/organisms/app-empty-state.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
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
          backgroundColor: AppColors.paper,
          appBar: AppBar(
            title: Text('SOCIAL', style: AppTypography.sectionHeader.copyWith(fontSize: 13, letterSpacing: 2)),
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.ink),
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
      return const Center(child: CircularProgressIndicator(color: AppColors.ink));
    }
    if (_vm.error != null) {
      return AppEmptyState(
        title: 'Something went wrong',
        body: _vm.error!,
        primaryLabel: 'Retry',
        onPrimary: () { _vm.clearError(); _vm.load(); },
        icon: Icons.error_outline,
      );
    }
    if (_vm.leaderboards.isEmpty) {
      return AppEmptyState(
        title: 'No Leaderboards Yet',
        body: 'Compete with friends and track weekly discipline scores.',
        primaryLabel: 'Create Leaderboard',
        onPrimary: () => _showCreateJoinSheet(context),
        icon: Icons.leaderboard_outlined,
      );
    }

    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: _vm.load,
      child: Column(
        children: [
          if (_vm.leaderboards.length > 1)
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                itemCount: _vm.leaderboards.length,
                itemBuilder: (context, i) {
                  final lb = _vm.leaderboards[i];
                  final selected = lb.id == _vm.selectedLeaderboard?.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: () => _vm.selectLeaderboard(lb),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        color: selected ? AppColors.ink : AppColors.paperAlt,
                        child: Text(
                          lb.name,
                          style: AppTypography.label.copyWith(
                            fontSize: 12,
                            color: selected ? AppColors.paper : AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          if (_vm.selectedLeaderboard != null)
            _LeaderboardHeader(vm: _vm, leaderboard: _vm.selectedLeaderboard!),

          Expanded(
            child: _vm.isLoadingRankings
                ? const Center(child: CircularProgressIndicator(color: AppColors.ink))
                : _vm.rankings.isEmpty
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('No members yet. Share your invite code.', textAlign: TextAlign.center),
                      ))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.xs, AppSpacing.base, AppSpacing.base),
                        itemCount: _vm.rankings.length,
                        itemBuilder: (context, i) => _RankingTile(
                          entry: _vm.rankings[i],
                          isCurrentUser: _vm.rankings[i].userId == _vm.currentUserId,
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
      builder: (_) => _CreateJoinSheet(vm: _vm),
    );
  }
}

class _LeaderboardHeader extends StatelessWidget {
  final LeaderboardViewModel vm;
  final LeaderboardEntity leaderboard;
  const _LeaderboardHeader({required this.vm, required this.leaderboard});

  @override
  Widget build(BuildContext context) {
    final myRank = vm.myRank;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.paperAlt,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leaderboard.name, style: AppTypography.heading.copyWith(fontSize: 15)),
                if (myRank > 0) Text('Your rank: #$myRank', style: AppTypography.labelMuted),
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
    return AppButton.secondary(
      inviteCode,
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: inviteCode));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invite code copied: $inviteCode')),
          );
        }
      },
      icon: Icons.copy,
    );
  }
}

class _RankingTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isCurrentUser;
  const _RankingTile({required this.entry, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final rank = entry.rank;
    final rankColor = switch (rank) {
      1 => AppColors.signal,
      2 => AppColors.paperBorder,
      3 => AppColors.inkMuted,
      _ => null,
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppColors.paperAlt : AppColors.paper,
        border: Border.all(
          color: isCurrentUser ? AppColors.ink : AppColors.paperBorder,
          width: isCurrentUser ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: rank <= 3
                  ? Container(width: 10, height: 10, color: rankColor)
                  : Text('#$rank', style: AppTypography.monoStrong.copyWith(fontSize: 12, color: AppColors.inkMuted)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(entry.displayName, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        const AppBadge('YOU', background: AppColors.ink, foreground: AppColors.paper),
                      ],
                    ],
                  ),
                  if (entry.streakCount > 0)
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department, size: 11, color: AppColors.signal),
                        const SizedBox(width: 2),
                        Text('${entry.streakCount}d streak', style: AppTypography.labelMuted),
                      ],
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${entry.weeklyScore}', style: AppTypography.monoStrong.copyWith(fontSize: 16)),
                Text('pts', style: AppTypography.labelMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Leaderboard', style: AppTypography.title),
          const SizedBox(height: AppSpacing.lg),

          Text('Create New', style: AppTypography.heading.copyWith(fontSize: 15)),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Leaderboard name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton.primary(
            'Create',
            isLoading: _creating,
            onPressed: _creating ? null : () {
              final name = _nameCtrl.text.trim();
              if (name.isEmpty) return;
              setState(() => _creating = true);
              widget.vm.createLeaderboard(name).then((_) {
                if (mounted) Navigator.pop(context);
              });
            },
            width: double.infinity,
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.base),
            child: Row(
              children: [
                Expanded(child: AppDivider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text('or'),
                ),
                Expanded(child: AppDivider()),
              ],
            ),
          ),

          Text('Join with Invite Code', style: AppTypography.heading.copyWith(fontSize: 15)),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _codeCtrl,
            decoration: const InputDecoration(labelText: 'Invite code'),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton.secondary(
            'Join',
            isLoading: _joining,
            onPressed: _joining ? null : () {
              final code = _codeCtrl.text.trim().toUpperCase();
              if (code.isEmpty) return;
              setState(() => _joining = true);
              widget.vm.joinByInviteCode(code).then((_) {
                if (mounted) Navigator.pop(context);
              });
            },
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}
