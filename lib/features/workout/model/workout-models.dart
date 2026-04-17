import '../../../core/entities/enums.dart';
import '../../../core/entities/exercise-entity.dart';

enum SessionMode { guided, manual }

enum ActiveSessionStatus { idle, running, resting, paused, completed }

class AiWorkoutInput {
  final String goals;
  final String trainingStyle;
  final List<String> focusAreas;
  final int minutesPerSession;
  final int sessionsPerWeek;
  final List<String> equipment;
  final String intensity;
  final String experienceLevel;

  const AiWorkoutInput({
    required this.goals,
    required this.trainingStyle,
    this.focusAreas = const [],
    required this.minutesPerSession,
    required this.sessionsPerWeek,
    this.equipment = const [],
    required this.intensity,
    required this.experienceLevel,
  });
}

/// A transient model used during workout builder sessions, holding the
/// exercise entity alongside the configuration for that plan entry.
class BuilderEntry {
  final ExerciseEntity exercise;
  int sets;
  int? reps;
  int? durationSeconds;
  int? restSeconds;
  double? weightKg;
  double? distanceKm;

  BuilderEntry({
    required this.exercise,
    this.sets = 3,
    this.reps,
    this.durationSeconds,
    this.restSeconds = 60,
    this.weightKg,
    this.distanceKm,
  }) {
    _applyDefaults();
  }

  void _applyDefaults() {
    switch (exercise.measurementType) {
      case ExerciseMeasurement.repsOnly:
        reps ??= 12;
      case ExerciseMeasurement.repsWeight:
        reps ??= 10;
        weightKg ??= 20;
      case ExerciseMeasurement.timeOnly:
        durationSeconds ??= 30;
      case ExerciseMeasurement.timeDistance:
        durationSeconds ??= 60;
        distanceKm ??= 0.4;
    }
  }

  bool get isValid {
    switch (exercise.measurementType) {
      case ExerciseMeasurement.repsOnly:
      case ExerciseMeasurement.repsWeight:
        return sets >= 1 && (reps ?? 0) >= 1;
      case ExerciseMeasurement.timeOnly:
      case ExerciseMeasurement.timeDistance:
        return sets >= 1 && (durationSeconds ?? 0) >= 1;
    }
  }
}

/// A model for an active set during a guided session.
class ActiveSet {
  final int exerciseIndex;
  final int setIndex;
  bool completed;

  ActiveSet({
    required this.exerciseIndex,
    required this.setIndex,
    this.completed = false,
  });
}
