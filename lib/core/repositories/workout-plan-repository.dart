import '../entities/workout-plan-entity.dart';

abstract class WorkoutPlanRepository {
  Future<List<WorkoutPlanEntity>> getUserPlans(String userId);

  Future<WorkoutPlanEntity?> getPlan(String id);

  Future<WorkoutPlanEntity> createPlan(WorkoutPlanEntity plan);

  Future<WorkoutPlanEntity> updatePlan(WorkoutPlanEntity plan);

  Future<void> deletePlan(String id);
}
