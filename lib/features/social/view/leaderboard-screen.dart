import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../app/app-router.dart';
import '../../../core/entities/leaderboard-entity.dart';
import '../../../infra/repository-locator.dart';
import '../../../shared/design/atoms/app-badge.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-divider.dart';
import '../../../shared/design/organisms/app-empty-state.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../view-model/friends-view-model.dart';
import '../view-model/leaderboard-view-model.dart';

class LeaderboardScreen extends StatefulWidget {
  final bool isActive;

  const LeaderboardScreen({super.key, this.isActive = true});

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
      achievementRepo: RepositoryLocator.instance.achievement,
    );
    _vm.load();
  }

  @override
  void didUpdateWidget(covariant LeaderboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _vm.load();
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
            title: Text(
              'SOCIAL',
              style: AppTypography.sectionHeader.copyWith(
                fontSize: 13,
                letterSpacing: 2,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.people_outline, color: AppColors.ink),
                tooltip: 'Friends',
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRouter.friends),
              ),
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
      return const Center(
        child: CircularProgressIndicator(color: AppColors.ink),
      );
    }
    if (_vm.error != null) {
      return AppEmptyState(
        title: 'Something went wrong',
        body: _vm.error!,
        primaryLabel: 'Retry',
        onPrimary: () {
          _vm.clearError();
          _vm.load();
        },
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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                itemCount: _vm.leaderboards.length,
                itemBuilder: (context, i) {
                  final lb = _vm.leaderboards[i];
                  final selected = lb.id == _vm.selectedLeaderboard?.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: () => _vm.selectLeaderboard(lb),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        color: selected ? AppColors.ink : AppColors.paperAlt,
                        child: Text(
                          lb.name,
                          style: AppTypography.label.copyWith(
                            fontSize: 12,
                            color: selected
                                ? AppColors.paper
                                : AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          if (_vm.selectedLeaderboard != null) ...[
            _LeaderboardHeader(vm: _vm, leaderboard: _vm.selectedLeaderboard!),
            const _ScoreExplanation(),
          ],

          Expanded(
            child: _vm.isLoadingRankings
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.ink),
                  )
                : _vm.rankings.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'No members yet. Share your invite code.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.base,
                      AppSpacing.xs,
                      AppSpacing.base,
                      AppSpacing.base,
                    ),
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
    final todayUtc = DateTime.now().toUtc();
    final weekStart = DateTime.utc(
      todayUtc.year,
      todayUtc.month,
      todayUtc.day,
    ).subtract(Duration(days: todayUtc.weekday - DateTime.monday));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final period =
        '${DateFormat('d MMM').format(weekStart)} – '
        '${DateFormat('d MMM y').format(weekEnd)} (UTC)';
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.base,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.paperAlt,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leaderboard.name,
                  style: AppTypography.heading.copyWith(fontSize: 15),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('Current week: $period', style: AppTypography.labelMuted),
                if (!vm.isLoadingRankings)
                  Text(
                    '${vm.rankings.length} ${vm.rankings.length == 1 ? 'member' : 'members'}',
                    style: AppTypography.labelMuted,
                  ),
                if (!vm.isLoadingRankings && myRank > 0)
                  Text('Your rank: #$myRank', style: AppTypography.labelMuted),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                tooltip: 'Invite friends',
                icon: const Icon(Icons.person_add_alt_1_outlined),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _InviteFriendsSheet(vm: vm),
                ),
              ),
              _InviteButton(inviteCode: leaderboard.inviteCode),
            ],
          ),
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

class _ScoreExplanation extends StatelessWidget {
  const _ScoreExplanation();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.base,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.paperBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOW WEEKLY SCORES WORK', style: AppTypography.sectionHeader),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '10 points per workout (at least 5 minutes)',
            style: AppTypography.labelMuted,
          ),
          Text(
            '1 point per 10 total qualifying workout minutes',
            style: AppTypography.labelMuted,
          ),
          Text(
            '5 points if your current streak is at least 7 days',
            style: AppTypography.labelMuted,
          ),
        ],
      ),
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
      2 => AppColors.ink,
      3 => AppColors.inkMuted,
      _ => AppColors.inkMuted,
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                '#$rank',
                style: AppTypography.monoStrong.copyWith(
                  fontSize: 12,
                  color: rankColor,
                ),
              ),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: isCurrentUser
                  ? AppColors.ink
                  : AppColors.paperAlt,
              child: Text(
                entry.displayName.trim().isEmpty
                    ? '?'
                    : entry.displayName.trim()[0].toUpperCase(),
                style: AppTypography.label.copyWith(
                  color: isCurrentUser ? AppColors.paper : AppColors.ink,
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
                      Flexible(
                        child: Text(
                          entry.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        const AppBadge(
                          'YOU',
                          background: AppColors.ink,
                          foreground: AppColors.paper,
                        ),
                      ],
                    ],
                  ),
                  if (entry.streakCount > 0)
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          size: 11,
                          color: AppColors.signal,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${entry.streakCount}d streak',
                          style: AppTypography.labelMuted,
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
                  style: AppTypography.monoStrong.copyWith(fontSize: 16),
                ),
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
  late final FriendsViewModel _friendsVm;
  final Set<String> _selectedFriendIds = {};
  bool _creating = false;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _friendsVm = FriendsViewModel(
      friendshipRepo: RepositoryLocator.instance.friendship,
      profileRepo: RepositoryLocator.instance.profile,
    )..load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _friendsVm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Leaderboard', style: AppTypography.title),
          const SizedBox(height: AppSpacing.lg),

          Text(
            'Create New',
            style: AppTypography.heading.copyWith(fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Leaderboard name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.md),
          ListenableBuilder(
            listenable: _friendsVm,
            builder: (context, _) {
              if (_friendsVm.isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (_friendsVm.friends.isEmpty) {
                return Text(
                  'No accepted friends yet. You can still create the leaderboard.',
                  style: AppTypography.labelMuted,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('INVITE FRIENDS', style: AppTypography.sectionHeader),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'They will join the leaderboard immediately.',
                    style: AppTypography.labelMuted,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ..._friendsVm.friends.map(
                    (friend) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _selectedFriendIds.contains(friend.profile.id),
                      title: Text(friend.displayName),
                      subtitle: friend.profile.streakCount > 0
                          ? Text('${friend.profile.streakCount}-day streak')
                          : null,
                      onChanged: _creating
                          ? null
                          : (selected) => setState(() {
                              if (selected ?? false) {
                                _selectedFriendIds.add(friend.profile.id);
                              } else {
                                _selectedFriendIds.remove(friend.profile.id);
                              }
                            }),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton.primary(
            'Create',
            isLoading: _creating,
            onPressed: _creating
                ? null
                : () {
                    final name = _nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    setState(() => _creating = true);
                    widget.vm
                        .createLeaderboard(
                          name,
                          friendIds: _selectedFriendIds.toList(),
                        )
                        .then((created) {
                          if (created && context.mounted) {
                            Navigator.pop(context);
                          } else if (mounted) {
                            setState(() => _creating = false);
                          }
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

          Text(
            'Join with Invite Code',
            style: AppTypography.heading.copyWith(fontSize: 15),
          ),
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
            onPressed: _joining
                ? null
                : () {
                    final code = _codeCtrl.text.trim().toUpperCase();
                    if (code.isEmpty) return;
                    setState(() => _joining = true);
                    widget.vm.joinByInviteCode(code).then((_) {
                      if (context.mounted) Navigator.pop(context);
                    });
                  },
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}

class _InviteFriendsSheet extends StatefulWidget {
  final LeaderboardViewModel vm;
  const _InviteFriendsSheet({required this.vm});

  @override
  State<_InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<_InviteFriendsSheet> {
  late final FriendsViewModel _friendsVm;
  final Set<String> _selectedFriendIds = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _friendsVm = FriendsViewModel(
      friendshipRepo: RepositoryLocator.instance.friendship,
      profileRepo: RepositoryLocator.instance.profile,
    )..load();
  }

  @override
  void dispose() {
    _friendsVm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        ),
        child: ListenableBuilder(
          listenable: _friendsVm,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Invite friends', style: AppTypography.title),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Accepted friends join immediately.',
                style: AppTypography.bodyMuted,
              ),
              const SizedBox(height: AppSpacing.md),
              if (_friendsVm.isLoading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_friendsVm.friends.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('You have no accepted friends to invite yet.'),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView(
                    shrinkWrap: true,
                    children: _friendsVm.friends
                        .map(
                          (friend) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _selectedFriendIds.contains(
                              friend.profile.id,
                            ),
                            title: Text(friend.displayName),
                            onChanged: _saving
                                ? null
                                : (selected) => setState(() {
                                    if (selected ?? false) {
                                      _selectedFriendIds.add(friend.profile.id);
                                    } else {
                                      _selectedFriendIds.remove(
                                        friend.profile.id,
                                      );
                                    }
                                  }),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              AppButton.primary(
                'Invite selected',
                width: double.infinity,
                isLoading: _saving,
                onPressed: _saving || _selectedFriendIds.isEmpty
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        setState(() => _saving = true);
                        final invited = await widget.vm.inviteFriends(
                          _selectedFriendIds.toList(),
                        );
                        if (!mounted) return;
                        if (invited) {
                          navigator.pop();
                        } else {
                          setState(() => _saving = false);
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
