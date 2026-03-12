class UserRewardEntity {
  final String id;
  final String userId;
  final String rewardTitle;
  final String? rewardDescription;
  final DateTime unlockedAt;

  const UserRewardEntity({
    required this.id,
    required this.userId,
    required this.rewardTitle,
    this.rewardDescription,
    required this.unlockedAt,
  });
}
