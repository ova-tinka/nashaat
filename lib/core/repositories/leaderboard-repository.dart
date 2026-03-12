import '../entities/leaderboard-entity.dart';

abstract class LeaderboardRepository {
  Future<List<LeaderboardEntity>> getUserLeaderboards(String userId);

  Future<LeaderboardEntity?> getLeaderboard(String id);

  Future<LeaderboardEntity?> getLeaderboardByInviteCode(String inviteCode);

  Future<LeaderboardEntity> createLeaderboard(
    String ownerId,
    String name,
    String inviteCode,
  );

  Future<List<LeaderboardMemberEntity>> getMembers(String leaderboardId);

  Future<LeaderboardMemberEntity> joinLeaderboard(
    String leaderboardId,
    String userId,
  );

  Future<void> updateMemberScore(
    String leaderboardId,
    String userId,
    int score,
  );
}
