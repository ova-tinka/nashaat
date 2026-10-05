import '../entities/workout-log-entity.dart';
import '../entities/workout-completion-result.dart';

abstract class WorkoutLogRepository {
  Future<List<WorkoutLogEntity>> getUserLogs(
    String userId, {
    int? limit,
    DateTime? from,
  });

  Future<WorkoutLogEntity?> getLog(String id);

  Future<WorkoutSessionEntity> startSession(String? workoutPlanId);

  Future<WorkoutCompletionResult> completeSession({
    required String sessionId,
    required List<CompletedExercise> completedExercises,
    String? notes,
  });
}
