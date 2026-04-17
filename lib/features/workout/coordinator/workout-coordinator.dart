import '../../../app/app-coordinator.dart';
import '../../../core/entities/workout-plan-entity.dart';

class WorkoutCoordinator {
  final AppCoordinator _app;

  WorkoutCoordinator(this._app);

  void goToBuilder({String? editPlanId}) =>
      _app.showWorkoutBuilder(editPlanId: editPlanId);

  void goToExerciseLibrary() => _app.showExerciseLibrary();

  void goToActiveSession(WorkoutPlanEntity plan) =>
      _app.showActiveSession(plan);

  void goToAiGeneration() => _app.showAiGeneration();
}
