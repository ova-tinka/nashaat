import '../../core/entities/enums.dart';
import '../../core/entities/workout-plan-entity.dart';

abstract final class DurationEstimator {
  static const int _secondsPerRep = 3;
  static const int _transitionSeconds = 30;
  static const double _bufferMultiplier = 1.1;

  /// Estimates the duration in seconds for a single exercise entry.
  static int estimateExerciseSeconds(
    WorkoutPlanExercise exercise,
    ExerciseMeasurement measurement,
  ) {
    final int setDurationSeconds = switch (measurement) {
      ExerciseMeasurement.repsOnly ||
      ExerciseMeasurement.repsWeight =>
        (exercise.reps ?? 10) * _secondsPerRep,
      ExerciseMeasurement.timeOnly ||
      ExerciseMeasurement.timeDistance =>
        exercise.durationSeconds ?? 30,
    };

    final int totalActiveSeconds = setDurationSeconds * exercise.sets;
    final int totalRestSeconds =
        (exercise.restSeconds ?? 60) * (exercise.sets - 1).clamp(0, 999);
    return totalActiveSeconds + totalRestSeconds;
  }

  /// Returns a (min, max) tuple in whole minutes for a list of exercises.
  ///
  /// [measurements] maps exerciseId → ExerciseMeasurement. Missing entries
  /// fall back to repsWeight.
  static (int min, int max) estimatePlanMinutes(
    List<WorkoutPlanExercise> exercises,
    Map<String, ExerciseMeasurement> measurements,
  ) {
    if (exercises.isEmpty) return (0, 0);

    int totalSeconds = 0;
    for (final e in exercises) {
      final measurement =
          measurements[e.exerciseId] ?? ExerciseMeasurement.repsWeight;
      totalSeconds += estimateExerciseSeconds(e, measurement);
    }

    // Add transition time between exercises (not after the last one).
    totalSeconds += _transitionSeconds * (exercises.length - 1);

    final int minMinutes = (totalSeconds / 60).round().clamp(1, 9999);
    final int maxMinutes =
        (totalSeconds * _bufferMultiplier / 60).round().clamp(minMinutes, 9999);

    return (minMinutes, maxMinutes);
  }

  /// Returns a human-readable duration range string, e.g. "28–35 min".
  static String formatEstimate(
    List<WorkoutPlanExercise> exercises,
    Map<String, ExerciseMeasurement> measurements,
  ) {
    final (min, max) = estimatePlanMinutes(exercises, measurements);
    if (min == 0) return '';
    if (min == max) return '$min min';
    return '$min–$max min';
  }
}
