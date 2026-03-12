import '../entities/workout-log-entity.dart';

abstract class WorkoutLogRepository {
  Future<List<WorkoutLogEntity>> getUserLogs(
    String userId, {
    int? limit,
    DateTime? from,
  });

  Future<WorkoutLogEntity?> getLog(String id);

  Future<WorkoutLogEntity> createLog(WorkoutLogEntity log);
}
