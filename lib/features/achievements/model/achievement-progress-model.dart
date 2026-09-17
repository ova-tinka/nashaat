import '../../../core/entities/achievement-entity.dart';
import '../../../core/entities/enums.dart';

enum AchievementDisplayStatus { locked, inProgress, unlocked }

class AchievementProgressModel {
  final AchievementDefinitionEntity definition;
  final UserAchievementEntity? userAchievement;

  const AchievementProgressModel({
    required this.definition,
    this.userAchievement,
  });

  int get progress => userAchievement?.progress ?? 0;
  DateTime? get unlockedAt => userAchievement?.unlockedAt;

  AchievementDisplayStatus get status {
    if (unlockedAt != null) return AchievementDisplayStatus.unlocked;
    if (progress > 0) return AchievementDisplayStatus.inProgress;
    return AchievementDisplayStatus.locked;
  }
}

extension AchievementProgressFormatting on AchievementProgressModel {
  String get statusLabel => switch (status) {
    AchievementDisplayStatus.locked => 'Locked',
    AchievementDisplayStatus.inProgress => 'In Progress',
    AchievementDisplayStatus.unlocked => 'Unlocked',
  };

  String get progressLabel {
    final suffix = definition.criteria == AchievementCriteria.currentStreak
        ? ' days'
        : '';
    return '$progress / ${definition.targetValue}$suffix';
  }

  String get rewardLabel => switch (definition.rewardType) {
    RewardType.points => '+${definition.rewardAmount} Points',
    RewardType.screenTime => '+${definition.rewardAmount} min Screen Time',
    RewardType.recognition => 'Recognition Badge',
  };

  String get criteriaLabel => switch (definition.criteria) {
    AchievementCriteria.qualifyingWorkoutCount =>
      'Complete ${definition.targetValue} qualifying ${definition.targetValue == 1 ? 'workout' : 'workouts'}',
    AchievementCriteria.currentStreak =>
      'Reach a ${definition.targetValue}-day workout streak',
    AchievementCriteria.leaderboardJoin => 'Join a private leaderboard',
    AchievementCriteria.weeklyLeaderboardWin =>
      'Win ${definition.targetValue} weekly leaderboard ${definition.targetValue == 1 ? 'round' : 'rounds'}',
  };
}
