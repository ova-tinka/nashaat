import 'enums.dart';

/// Represents a single exercise entry inside a workout plan's JSONB document.
class WorkoutPlanExercise {
  final String exerciseId;
  final String exerciseName;
  final int sets;
  final int? reps;
  final int? durationSeconds;
  final double? weightKg;
  final double? distanceKm;

  const WorkoutPlanExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    this.reps,
    this.durationSeconds,
    this.weightKg,
    this.distanceKm,
  });
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
    required this.createdAt,
    required this.updatedAt,
  });

  WorkoutPlanEntity copyWith({
    String? title,
    String? description,
    WorkoutSource? source,
    List<int>? scheduledDays,
    List<WorkoutPlanExercise>? exercises,
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
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
