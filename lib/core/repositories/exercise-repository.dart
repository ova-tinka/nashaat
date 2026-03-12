import '../entities/exercise-entity.dart';

abstract class ExerciseRepository {
  Future<List<ExerciseEntity>> getAllExercises();

  Future<List<ExerciseEntity>> searchExercises(String query);

  Future<ExerciseEntity?> getExercise(String id);

  Future<ExerciseEntity> createExercise(ExerciseEntity exercise);
}
