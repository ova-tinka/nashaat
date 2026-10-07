import '../../core/entities/leaderboard-entity.dart';
import '../../core/repositories/leaderboard-repository.dart';
import '../../shared/logger.dart';
import 'supabase-client.dart';

class SupabaseLeaderboardRepository implements LeaderboardRepository {
  final _db = SupabaseClientProvider.client;

  @override
  Future<List<LeaderboardEntity>> getUserLeaderboards(String userId) async {
    final memberRows = await _db
        .from('leaderboard_members')
        .select('leaderboard_id')
        .eq('user_id', userId);

    final ids = (memberRows as List)
        .map((e) => e['leaderboard_id'] as String)
        .toList();

    if (ids.isEmpty) return [];

    final data = await _db
        .from('leaderboards')
        .select()
        .inFilter('id', ids)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => _fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<LeaderboardEntity?> getLeaderboard(String id) async {
    final data = await _db
        .from('leaderboards')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return _fromMap(data);
  }

  @override
  Future<LeaderboardEntity?> getLeaderboardByInviteCode(
    String inviteCode,
  ) async {
    final data = await _db.rpc(
      'find_active_leaderboard_by_invite',
      params: {'p_invite_code': inviteCode},
    );
    final rows = data as List;
    if (rows.isEmpty) return null;
    return _fromMap(rows.first as Map<String, dynamic>);
  }

  @override
  Future<LeaderboardEntity> createLeaderboard(
    String name,
    String inviteCode,
    List<String> friendIds,
  ) async {
    Log.db('creating leaderboard: $name');
    final data = await _db.rpc(
      'create_leaderboard_with_members',
      params: {
        'p_name': name,
        'p_invite_code': inviteCode,
        'p_friend_ids': friendIds,
      },
    );

    Log.db('leaderboard created ✓');
    return _fromMap(data);
  }

  @override
  Future<void> inviteFriends(
    String leaderboardId,
    List<String> friendIds,
  ) async {
    if (friendIds.isEmpty) return;
    await _db.rpc(
      'invite_friends_to_leaderboard',
      params: {'p_leaderboard_id': leaderboardId, 'p_friend_ids': friendIds},
    );
  }

  @override
  Future<List<LeaderboardMemberEntity>> getMembers(String leaderboardId) async {
    final data = await _db
        .from('leaderboard_members')
        .select()
        .eq('leaderboard_id', leaderboardId)
        .order('weekly_score', ascending: false);
    return (data as List)
        .map((e) => _memberFromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<LeaderboardMemberEntity> joinLeaderboard(
    String leaderboardId,
    String userId,
  ) async {
    final data = await _db
        .from('leaderboard_members')
        .insert({'leaderboard_id': leaderboardId, 'user_id': userId})
        .select()
        .single();
    return _memberFromMap(data);
  }

  @override
  Future<void> recalculateMyWeeklyScore() async {
    await _db.rpc('recalculate_my_weekly_leaderboard_score');
    Log.db('weekly leaderboard score recalculated');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  LeaderboardEntity _fromMap(Map<String, dynamic> map) => LeaderboardEntity(
    id: map['id'] as String,
    ownerId: map['owner_id'] as String,
    name: map['name'] as String,
    inviteCode: map['invite_code'] as String,
    isActive: map['is_active'] as bool? ?? true,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  LeaderboardMemberEntity _memberFromMap(Map<String, dynamic> map) =>
      LeaderboardMemberEntity(
        leaderboardId: map['leaderboard_id'] as String,
        userId: map['user_id'] as String,
        weeklyScore: map['weekly_score'] as int? ?? 0,
        joinedAt: DateTime.parse(map['joined_at'] as String),
      );
}
