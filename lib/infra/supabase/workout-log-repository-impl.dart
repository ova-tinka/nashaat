import '../../core/entities/workout-log-entity.dart';
import '../../core/repositories/workout-log-repository.dart';
import '../../shared/logger.dart';
import 'supabase-client.dart';

class SupabaseWorkoutLogRepository implements WorkoutLogRepository {
  final _db = SupabaseClientProvider.client;

  @override
  Future<List<WorkoutLogEntity>> getUserLogs(
    String userId, {
    int? limit,
    DateTime? from,
  }) async {
    var filterQuery = _db
        .from('workout_logs')
        .select()
        .eq('user_id', userId);

    if (from != null) {
      filterQuery = filterQuery.gte('logged_at', from.toIso8601String());
    }

    var transformQuery = filterQuery.order('logged_at', ascending: false);
    if (limit != null) {
      transformQuery = transformQuery.limit(limit);
    }

    final data = await transformQuery;
    final logs = (data as List)
        .map((e) => _fromMap(e as Map<String, dynamic>))
        .toList();
    Log.db('loaded ${logs.length} workout log(s)');
    return logs;
  }

  @override
  Future<WorkoutLogEntity?> getLog(String id) async {
    final data = await _db
        .from('workout_logs')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return _fromMap(data);
  }

  @override
  Future<WorkoutLogEntity> createLog(WorkoutLogEntity log) async {
    Log.db('logging workout: ${log.durationMinutes} min, earned ${log.earnedScreenTimeMinutes} min');
    final data = await _db
        .from('workout_logs')
        .insert({
          'user_id': log.userId,
          if (log.workoutPlanId != null) 'workout_plan_id': log.workoutPlanId,
          'duration_minutes': log.durationMinutes,
          'earned_screen_time_minutes': log.earnedScreenTimeMinutes,
          'completed_exercises':
              log.completedExercises.map(_completedToMap).toList(),
          if (log.notes != null) 'notes': log.notes,
          'logged_at': log.loggedAt.toIso8601String(),
        })
        .select()
        .single();
    Log.db('workout log created ✓');
    return _fromMap(data);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  WorkoutLogEntity _fromMap(Map<String, dynamic> map) {
    final exercisesRaw = map['completed_exercises'] as List<dynamic>? ?? [];
    return WorkoutLogEntity(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      workoutPlanId: map['workout_plan_id'] as String?,
      durationMinutes: map['duration_minutes'] as int,
      earnedScreenTimeMinutes: map['earned_screen_time_minutes'] as int,
      completedExercises: exercisesRaw
          .map((e) => _completedFromMap(e as Map<String, dynamic>))
          .toList(),
      notes: map['notes'] as String?,
      loggedAt: DateTime.parse(map['logged_at'] as String),
    );
  }

  CompletedExercise _completedFromMap(Map<String, dynamic> map) =>
      CompletedExercise(
        exerciseId: map['exercise_id'] as String,
        exerciseName: map['exercise_name'] as String,
        setsCompleted: map['sets_completed'] as int? ?? 0,
        repsCompleted: map['reps_completed'] as int?,
        durationSeconds: map['duration_seconds'] as int?,
        weightKg: (map['weight_kg'] as num?)?.toDouble(),
        distanceKm: (map['distance_km'] as num?)?.toDouble(),
      );

  Map<String, dynamic> _completedToMap(CompletedExercise e) => {
        'exercise_id': e.exerciseId,
        'exercise_name': e.exerciseName,
        'sets_completed': e.setsCompleted,
        if (e.repsCompleted != null) 'reps_completed': e.repsCompleted,
        if (e.durationSeconds != null) 'duration_seconds': e.durationSeconds,
        if (e.weightKg != null) 'weight_kg': e.weightKg,
        if (e.distanceKm != null) 'distance_km': e.distanceKm,
      };
}
