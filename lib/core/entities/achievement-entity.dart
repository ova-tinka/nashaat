import 'enums.dart';

class AchievementDefinitionEntity {
  final String id;
  final String code;
  final String name;
  final String description;
  final AchievementCategory category;
  final AchievementCriteria criteria;
  final int targetValue;
  final RewardType rewardType;
  final int rewardAmount;
  final String? iconReference;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AchievementDefinitionEntity({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.category,
    required this.criteria,
    required this.targetValue,
    required this.rewardType,
    required this.rewardAmount,
    this.iconReference,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
}

class UserAchievementEntity {
  final String id;
  final String userId;
  final String achievementId;
  final int progress;
  final DateTime? unlockedAt;
  final DateTime? rewardGrantedAt;
  final String? rewardTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserAchievementEntity({
    required this.id,
    required this.userId,
    required this.achievementId,
    required this.progress,
    this.unlockedAt,
    this.rewardGrantedAt,
    this.rewardTransactionId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isUnlocked => unlockedAt != null;
}

/// An achievement unlocked by the latest server-side evaluation.
class UnlockedAchievementEntity {
  final String id;
  final String code;
  final String name;
  final RewardType rewardType;
  final int rewardAmount;

  const UnlockedAchievementEntity({
    required this.id,
    required this.code,
    required this.name,
    required this.rewardType,
    required this.rewardAmount,
  });
}
