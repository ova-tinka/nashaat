class LeaderboardEntity {
  final String id;
  final String ownerId;
  final String name;
  final String inviteCode;
  final bool isActive;
  final DateTime createdAt;

  const LeaderboardEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.inviteCode,
    this.isActive = true,
    required this.createdAt,
  });
}

class LeaderboardMemberEntity {
  final String leaderboardId;
  final String userId;
  final int weeklyScore;
  final DateTime joinedAt;

  const LeaderboardMemberEntity({
    required this.leaderboardId,
    required this.userId,
    this.weeklyScore = 0,
    required this.joinedAt,
  });

  LeaderboardMemberEntity copyWith({int? weeklyScore}) {
    return LeaderboardMemberEntity(
      leaderboardId: leaderboardId,
      userId: userId,
      weeklyScore: weeklyScore ?? this.weeklyScore,
      joinedAt: joinedAt,
    );
  }
}
