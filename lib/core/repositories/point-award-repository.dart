import '../entities/point-award-entity.dart';

abstract class PointAwardRepository {
  Future<WorkoutPointsResult> awardWorkoutPoints(String workoutLogId);

  Future<StreakMilestoneResult> awardStreakMilestonePoints(
    String workoutLogId,
  );

  Future<List<PointAwardEntity>> getUserPointAwards(
    String userId, {
    int? limit,
  });
}
