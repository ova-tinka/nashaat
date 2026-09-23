import 'enums.dart';

class PointAwardEntity {
  final String id;
  final String userId;
  final int points;
  final PointReason reason;
  final String description;
  final String sourceType;
  final String sourceEventId;
  final String? workoutLogId;
  final DateTime createdAt;

  const PointAwardEntity({
    required this.id,
    required this.userId,
    required this.points,
    required this.reason,
    required this.description,
    required this.sourceType,
    required this.sourceEventId,
    this.workoutLogId,
    required this.createdAt,
  });
}

class WorkoutPointsResult {
  final int pointsEarned;
  final int pointsTotal;
  final int currentStreak;
  final int longestStreak;

  const WorkoutPointsResult({
    required this.pointsEarned,
    required this.pointsTotal,
    required this.currentStreak,
    required this.longestStreak,
  });
}

class StreakMilestoneResult {
  final int streakDays;
  final int bonusPoints;
  final int pointsTotal;

  const StreakMilestoneResult({
    required this.streakDays,
    required this.bonusPoints,
    required this.pointsTotal,
  });
}
