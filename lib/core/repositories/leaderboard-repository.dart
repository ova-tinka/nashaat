import '../entities/leaderboard-entity.dart';

abstract class LeaderboardRepository {
  Future<List<LeaderboardEntity>> getUserLeaderboards(String userId);

  Future<LeaderboardEntity?> getLeaderboard(String id);

  Future<LeaderboardEntity?> getLeaderboardByInviteCode(String inviteCode);

  Future<LeaderboardEntity> createLeaderboard(
    String name,
    String inviteCode,
    List<String> friendIds,
  );

  Future<void> inviteFriends(String leaderboardId, List<String> friendIds);

  Future<List<LeaderboardMemberEntity>> getMembers(String leaderboardId);

  Future<LeaderboardMemberEntity> joinLeaderboard(
    String leaderboardId,
    String userId,
  );

  Future<void> recalculateMyWeeklyScore();
}
