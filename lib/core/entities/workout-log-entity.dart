/// Represents an exercise as actually completed during a session (JSONB).
class CompletedExercise {
  final String exerciseId;
  final String exerciseName;
  final int setsCompleted;
  final int? repsCompleted;
  final int? durationSeconds;
  final double? weightKg;
  final double? distanceKm;

  const CompletedExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.setsCompleted,
    this.repsCompleted,
    this.durationSeconds,
    this.weightKg,
    this.distanceKm,
  });
}

class WorkoutLogEntity {
  final String id;
  final String userId;
  final String? workoutPlanId;
  final int durationMinutes;
  final int earnedScreenTimeMinutes;
  final List<CompletedExercise> completedExercises;
  final String? notes;
  final DateTime loggedAt;

  const WorkoutLogEntity({
    required this.id,
    required this.userId,
    this.workoutPlanId,
    required this.durationMinutes,
    required this.earnedScreenTimeMinutes,
    this.completedExercises = const [],
    this.notes,
    required this.loggedAt,
  });
}
