import 'enums.dart';

/// Represents a single exercise entry inside a workout plan's JSONB document.
class WorkoutPlanExercise {
  final String exerciseId;
  final String exerciseName;
  final int sets;
  final int? reps;
  final int? durationSeconds;
  final int? restSeconds;
  final double? weightKg;
  final double? distanceKm;

  const WorkoutPlanExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    this.reps,
    this.durationSeconds,
    this.restSeconds,
    this.weightKg,
    this.distanceKm,
  });

  WorkoutPlanExercise copyWith({
    String? exerciseId,
    String? exerciseName,
    int? sets,
    int? reps,
    int? durationSeconds,
    int? restSeconds,
    double? weightKg,
    double? distanceKm,
  }) {
    return WorkoutPlanExercise(
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      weightKg: weightKg ?? this.weightKg,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }
}

class WorkoutPlanEntity {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final WorkoutSource source;
  /// Days of the week (1 = Monday … 7 = Sunday)
  final List<int> scheduledDays;
  final List<WorkoutPlanExercise> exercises;
  final SessionSize sessionSize;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkoutPlanEntity({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.source = WorkoutSource.manual,
    this.scheduledDays = const [],
    this.exercises = const [],
    this.sessionSize = SessionSize.small,
    required this.createdAt,
    required this.updatedAt,
  });

  WorkoutPlanEntity copyWith({
    String? title,
    String? description,
    WorkoutSource? source,
    List<int>? scheduledDays,
    List<WorkoutPlanExercise>? exercises,
    SessionSize? sessionSize,
    DateTime? updatedAt,
  }) {
    return WorkoutPlanEntity(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      source: source ?? this.source,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      exercises: exercises ?? this.exercises,
      sessionSize: sessionSize ?? this.sessionSize,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
