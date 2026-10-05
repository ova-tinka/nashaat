import 'achievement-entity.dart';

class WorkoutSessionEntity {
  final String id;
  final DateTime startedAt;

  const WorkoutSessionEntity({required this.id, required this.startedAt});
}

class WorkoutCompletionResult {
  final String workoutLogId;
  final int earnedScreenTimeMinutes;
  final int pointsEarned;
  final int pointsTotal;
  final int currentStreak;
  final int longestStreak;
  final int weeklyScore;
  final List<UnlockedAchievementEntity> newlyUnlockedAchievements;

  const WorkoutCompletionResult({
    required this.workoutLogId,
    required this.earnedScreenTimeMinutes,
    required this.pointsEarned,
    required this.pointsTotal,
    required this.currentStreak,
    required this.longestStreak,
    required this.weeklyScore,
    this.newlyUnlockedAchievements = const [],
  });
}
