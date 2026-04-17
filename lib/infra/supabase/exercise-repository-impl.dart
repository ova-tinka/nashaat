import '../../core/entities/enums.dart';
import '../../core/entities/exercise-entity.dart';
import '../../core/repositories/exercise-repository.dart';
import '../../shared/logger.dart';
import 'supabase-client.dart';

class SupabaseExerciseRepository implements ExerciseRepository {
  final _db = SupabaseClientProvider.client;

  @override
  Future<List<ExerciseEntity>> getAllExercises() async {
    final data = await _db.from('exercises').select().order('name');
    final exercises = (data as List)
        .map((e) => _fromMap(e as Map<String, dynamic>))
        .toList();
    Log.db('loaded ${exercises.length} exercise(s)');
    return exercises;
  }

  @override
  Future<List<ExerciseEntity>> searchExercises(String query) async {
    final data = await _db
        .from('exercises')
        .select()
        .ilike('name', '%$query%')
        .order('name');
    return (data as List)
        .map((e) => _fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ExerciseEntity?> getExercise(String id) async {
    final data = await _db
        .from('exercises')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return _fromMap(data);
  }

  @override
  Future<ExerciseEntity> createExercise(ExerciseEntity exercise) async {
    Log.db('creating exercise: ${exercise.name}');
    final data = await _db
        .from('exercises')
        .insert({
          'name': exercise.name,
          'description': exercise.description,
          'muscle_groups': exercise.muscleGroups,
          'steps': exercise.steps,
          'difficulty_level': _difficultyToString(exercise.difficultyLevel),
          'measurement_type': _measurementToString(exercise.measurementType),
          'media_id': exercise.mediaId,
          'is_system': exercise.isSystem,
        })
        .select()
        .single();
    return _fromMap(data);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  ExerciseEntity _fromMap(Map<String, dynamic> map) {
    final rawMuscleGroups = map['muscle_groups'];
    final List<String> muscleGroups;
    if (rawMuscleGroups is List) {
      muscleGroups = rawMuscleGroups.cast<String>();
    } else if (map['muscle_group'] is String) {
      muscleGroups = [map['muscle_group'] as String];
    } else {
      muscleGroups = [];
    }

    final rawSteps = map['steps'];
    final List<String> steps = rawSteps is List ? rawSteps.cast<String>() : [];

    return ExerciseEntity(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      muscleGroups: muscleGroups,
      steps: steps,
      difficultyLevel: _parseDifficulty(map['difficulty_level'] as String?),
      measurementType: _parseMeasurement(map['measurement_type'] as String? ?? 'reps_weight'),
      mediaId: map['media_id'] as String?,
      isSystem: map['is_system'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  DifficultyLevel _parseDifficulty(String? s) => switch (s) {
        'easy' => DifficultyLevel.easy,
        'hard' => DifficultyLevel.hard,
        _ => DifficultyLevel.medium,
      };

  String _difficultyToString(DifficultyLevel d) => switch (d) {
        DifficultyLevel.easy => 'easy',
        DifficultyLevel.medium => 'medium',
        DifficultyLevel.hard => 'hard',
      };

  ExerciseMeasurement _parseMeasurement(String s) => switch (s) {
        'time_distance' => ExerciseMeasurement.timeDistance,
        'time_only' => ExerciseMeasurement.timeOnly,
        'reps_only' => ExerciseMeasurement.repsOnly,
        _ => ExerciseMeasurement.repsWeight,
      };

  String _measurementToString(ExerciseMeasurement m) => switch (m) {
        ExerciseMeasurement.repsWeight => 'reps_weight',
        ExerciseMeasurement.timeDistance => 'time_distance',
        ExerciseMeasurement.timeOnly => 'time_only',
        ExerciseMeasurement.repsOnly => 'reps_only',
      };
}
