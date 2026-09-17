import '../../core/entities/enums.dart';
import '../../core/entities/point-award-entity.dart';
import '../../core/repositories/point-award-repository.dart';
import '../../shared/logger.dart';
import 'supabase-client.dart';

class SupabasePointAwardRepository implements PointAwardRepository {
  final _db = SupabaseClientProvider.client;

  @override
  Future<WorkoutPointsResult> awardWorkoutPoints(String workoutLogId) async {
    final data = await _db.rpc(
      'award_workout_points',
      params: {'p_workout_log_id': workoutLogId},
    );

    final Map<String, dynamic> row;
    if (data is List && data.isNotEmpty) {
      row = data.first as Map<String, dynamic>;
    } else if (data is Map<String, dynamic>) {
      row = data;
    } else {
      throw StateError('award_workout_points returned no result.');
    }

    final result = WorkoutPointsResult(
      pointsEarned: (row['points_earned'] as num?)?.toInt() ?? 0,
      pointsTotal: (row['points_total'] as num?)?.toInt() ?? 0,
      currentStreak: (row['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (row['longest_streak'] as num?)?.toInt() ?? 0,
    );
    Log.db(
      'workout points evaluated: +${result.pointsEarned}, '
      'total ${result.pointsTotal}, streak ${result.currentStreak}',
    );
    return result;
  }

  @override
  Future<StreakMilestoneResult> awardStreakMilestonePoints(
    String workoutLogId,
  ) async {
    final data = await _db.rpc(
      'award_streak_milestone_points',
      params: {'p_workout_log_id': workoutLogId},
    );

    final Map<String, dynamic> row;
    if (data is List && data.isNotEmpty) {
      row = data.first as Map<String, dynamic>;
    } else if (data is Map<String, dynamic>) {
      row = data;
    } else {
      throw StateError(
        'award_streak_milestone_points returned no result.',
      );
    }

    final result = StreakMilestoneResult(
      streakDays: (row['streak_days'] as num?)?.toInt() ?? 0,
      bonusPoints: (row['bonus_points'] as num?)?.toInt() ?? 0,
      pointsTotal: (row['points_total'] as num?)?.toInt() ?? 0,
    );
    Log.db(
      'streak milestone evaluated: ${result.streakDays} days, '
      '+${result.bonusPoints}, total ${result.pointsTotal}',
    );
    return result;
  }

  @override
  Future<List<PointAwardEntity>> getUserPointAwards(
    String userId, {
    int? limit,
  }) async {
    var query = _db
        .from('point_awards')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    if (limit != null) {
      query = query.limit(limit);
    }

    final data = await query;
    final awards = (data as List)
        .map((row) => _fromMap(row as Map<String, dynamic>))
        .toList();
    Log.db('loaded ${awards.length} point award(s)');
    return awards;
  }

  PointAwardEntity _fromMap(Map<String, dynamic> map) => PointAwardEntity(
    id: map['id'] as String,
    userId: map['user_id'] as String,
    points: map['points'] as int,
    reason: _parseReason(map['reason_type'] as String),
    description: map['description'] as String,
    sourceType: map['source_type'] as String,
    sourceEventId: map['source_event_id'] as String,
    workoutLogId: map['workout_log_id'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  PointReason _parseReason(String value) => switch (value) {
    'streak_bonus' => PointReason.streakBonus,
    'achievement_bonus' => PointReason.achievementBonus,
    'manual_adjustment' => PointReason.manualAdjustment,
    _ => PointReason.workoutCompletion,
  };
}
