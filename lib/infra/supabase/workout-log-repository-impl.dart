import '../../core/entities/workout-log-entity.dart';
import '../../core/entities/achievement-entity.dart';
import '../../core/entities/enums.dart';
import '../../core/entities/workout-completion-result.dart';
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
    var filterQuery = _db.from('workout_logs').select().eq('user_id', userId);

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
  Future<WorkoutSessionEntity> startSession(String? workoutPlanId) async {
    final data = await _db.rpc(
      'start_workout_session',
      params: {'p_workout_plan_id': workoutPlanId},
    );
    final row = _firstRow(data);
    return WorkoutSessionEntity(
      id: row['session_id'] as String,
      startedAt: DateTime.parse(row['started_at'] as String),
    );
  }

  @override
  Future<WorkoutCompletionResult> completeSession({
    required String sessionId,
    required List<CompletedExercise> completedExercises,
    String? notes,
  }) async {
    final data = await _db.rpc(
      'complete_workout_session',
      params: {
        'p_session_id': sessionId,
        'p_completed_exercises': completedExercises
            .map(_completedToMap)
            .toList(),
        'p_notes': notes,
      },
    );
    final row = _firstRow(data);
    final unlockedRaw = row['newly_unlocked_achievements'];
    final unlocked = unlockedRaw is List
        ? unlockedRaw
              .map(
                (item) =>
                    _unlockedAchievementFromMap(item as Map<String, dynamic>),
              )
              .toList()
        : const <UnlockedAchievementEntity>[];

    return WorkoutCompletionResult(
      workoutLogId: row['workout_log_id'] as String,
      earnedScreenTimeMinutes:
          (row['earned_screen_time_minutes'] as num?)?.toInt() ?? 0,
      pointsEarned: (row['points_earned'] as num?)?.toInt() ?? 0,
      pointsTotal: (row['points_total'] as num?)?.toInt() ?? 0,
      currentStreak: (row['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (row['longest_streak'] as num?)?.toInt() ?? 0,
      weeklyScore: (row['weekly_score'] as num?)?.toInt() ?? 0,
      newlyUnlockedAchievements: unlocked,
    );
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

  UnlockedAchievementEntity _unlockedAchievementFromMap(
    Map<String, dynamic> map,
  ) => UnlockedAchievementEntity(
    id: map['id'] as String,
    code: map['code'] as String,
    name: map['name'] as String,
    rewardType: _parseRewardType(map['reward_type'] as String),
    rewardAmount: (map['reward_amount'] as num?)?.toInt() ?? 0,
  );

  RewardType _parseRewardType(String value) => switch (value) {
    'points' => RewardType.points,
    'screen_time' => RewardType.screenTime,
    _ => RewardType.recognition,
  };

  Map<String, dynamic> _firstRow(dynamic data) {
    if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
      return data.first as Map<String, dynamic>;
    }
    if (data is Map<String, dynamic>) return data;
    throw StateError('Workout RPC returned no result.');
  }

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
