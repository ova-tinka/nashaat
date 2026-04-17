import '../../core/entities/enums.dart';
import '../../core/entities/workout-plan-entity.dart';
import '../../core/repositories/workout-plan-repository.dart';
import '../../shared/logger.dart';
import 'supabase-client.dart';

class SupabaseWorkoutPlanRepository implements WorkoutPlanRepository {
  final _db = SupabaseClientProvider.client;

  @override
  Future<List<WorkoutPlanEntity>> getUserPlans(String userId) async {
    final data = await _db
        .from('workout_plans')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    final plans = (data as List)
        .map((e) => _fromMap(e as Map<String, dynamic>))
        .toList();
    Log.db('loaded ${plans.length} workout plan(s) for ${userId.substring(0, 8)}…');
    return plans;
  }

  @override
  Future<WorkoutPlanEntity?> getPlan(String id) async {
    final data = await _db
        .from('workout_plans')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return _fromMap(data);
  }

  @override
  Future<WorkoutPlanEntity> createPlan(WorkoutPlanEntity plan) async {
    Log.db('creating workout plan: ${plan.title}');
    final data = await _db
        .from('workout_plans')
        .insert({
          'user_id': plan.userId,
          'title': plan.title,
          'description': plan.description,
          'source': _sourceToString(plan.source),
          'scheduled_days': plan.scheduledDays,
          'exercises': plan.exercises.map(_exerciseToMap).toList(),
          'session_size': _sessionSizeToString(plan.sessionSize),
        })
        .select()
        .single();
    Log.db('plan created ✓ id ${(data['id'] as String).substring(0, 8)}…');
    return _fromMap(data);
  }

  @override
  Future<WorkoutPlanEntity> updatePlan(WorkoutPlanEntity plan) async {
    Log.db('updating plan ${plan.id.substring(0, 8)}…');
    final data = await _db
        .from('workout_plans')
        .update({
          'title': plan.title,
          'description': plan.description,
          'source': _sourceToString(plan.source),
          'scheduled_days': plan.scheduledDays,
          'exercises': plan.exercises.map(_exerciseToMap).toList(),
          'session_size': _sessionSizeToString(plan.sessionSize),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', plan.id)
        .select()
        .single();
    return _fromMap(data);
  }

  @override
  Future<void> deletePlan(String id) async {
    Log.db('deleting plan ${id.substring(0, 8)}…');
    await _db.from('workout_plans').delete().eq('id', id);
    Log.db('plan deleted ✓');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  WorkoutPlanEntity _fromMap(Map<String, dynamic> map) {
    final exercisesRaw = map['exercises'] as List<dynamic>? ?? [];
    return WorkoutPlanEntity(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      source: _parseSource(map['source'] as String? ?? 'manual'),
      scheduledDays: _parseIntList(map['scheduled_days']),
      exercises: exercisesRaw
          .map((e) => _exerciseFromMap(e as Map<String, dynamic>))
          .toList(),
      sessionSize: _parseSessionSize(map['session_size'] as String? ?? 'small'),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  WorkoutPlanExercise _exerciseFromMap(Map<String, dynamic> map) =>
      WorkoutPlanExercise(
        exerciseId: map['exercise_id'] as String,
        exerciseName: map['exercise_name'] as String,
        sets: map['sets'] as int? ?? 1,
        reps: map['reps'] as int?,
        durationSeconds: map['duration_seconds'] as int?,
        restSeconds: map['rest_seconds'] as int?,
        weightKg: (map['weight_kg'] as num?)?.toDouble(),
        distanceKm: (map['distance_km'] as num?)?.toDouble(),
      );

  Map<String, dynamic> _exerciseToMap(WorkoutPlanExercise e) => {
        'exercise_id': e.exerciseId,
        'exercise_name': e.exerciseName,
        'sets': e.sets,
        if (e.reps != null) 'reps': e.reps,
        if (e.durationSeconds != null) 'duration_seconds': e.durationSeconds,
        if (e.restSeconds != null) 'rest_seconds': e.restSeconds,
        if (e.weightKg != null) 'weight_kg': e.weightKg,
        if (e.distanceKm != null) 'distance_km': e.distanceKm,
      };

  List<int> _parseIntList(dynamic raw) {
    if (raw is List) return raw.map((e) => e as int).toList();
    return [];
  }

  WorkoutSource _parseSource(String s) =>
      s == 'ai_generated' ? WorkoutSource.aiGenerated : WorkoutSource.manual;

  String _sourceToString(WorkoutSource s) =>
      s == WorkoutSource.aiGenerated ? 'ai_generated' : 'manual';

  SessionSize _parseSessionSize(String s) =>
      s == 'big' ? SessionSize.big : SessionSize.small;

  String _sessionSizeToString(SessionSize s) =>
      s == SessionSize.big ? 'big' : 'small';
}
