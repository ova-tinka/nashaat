import '../../core/entities/achievement-entity.dart';
import '../../core/entities/enums.dart';
import '../../core/repositories/achievement-repository.dart';
import '../../shared/logger.dart';
import 'supabase-client.dart';

class SupabaseAchievementRepository implements AchievementRepository {
  final _db = SupabaseClientProvider.client;

  @override
  Future<List<UnlockedAchievementEntity>> evaluateUserAchievements() async {
    final data = await _db.rpc('evaluate_user_achievements');
    final rows = data is List
        ? data
        : data is Map<String, dynamic>
        ? [data]
        : const <dynamic>[];

    final unlocked = rows
        .map((row) => _unlockedAchievementFromMap(row as Map<String, dynamic>))
        .toList();
    Log.db('achievement evaluation unlocked ${unlocked.length} achievement(s)');
    return unlocked;
  }

  @override
  Future<List<AchievementDefinitionEntity>> getDefinitions({
    bool activeOnly = true,
  }) async {
    var query = _db.from('achievement_definitions').select();
    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final data = await query.order('target_value');
    final definitions = (data as List)
        .map((row) => _definitionFromMap(row as Map<String, dynamic>))
        .toList();
    Log.db('loaded ${definitions.length} achievement definition(s)');
    return definitions;
  }

  @override
  Future<List<UserAchievementEntity>> getUserAchievements(String userId) async {
    final data = await _db
        .from('user_achievements')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    final achievements = (data as List)
        .map((row) => _userAchievementFromMap(row as Map<String, dynamic>))
        .toList();
    Log.db('loaded ${achievements.length} user achievement(s)');
    return achievements;
  }

  AchievementDefinitionEntity _definitionFromMap(Map<String, dynamic> map) =>
      AchievementDefinitionEntity(
        id: map['id'] as String,
        code: map['code'] as String,
        name: map['name'] as String,
        description: map['description'] as String,
        category: _parseCategory(map['category'] as String),
        criteria: _parseCriteria(map['criteria_type'] as String),
        targetValue: map['target_value'] as int,
        rewardType: _parseRewardType(map['reward_type'] as String),
        rewardAmount: map['reward_amount'] as int? ?? 0,
        iconReference: map['icon_reference'] as String?,
        isActive: map['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  UserAchievementEntity _userAchievementFromMap(Map<String, dynamic> map) =>
      UserAchievementEntity(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        achievementId: map['achievement_id'] as String,
        progress: map['progress'] as int? ?? 0,
        unlockedAt: _parseOptionalDate(map['unlocked_at']),
        rewardGrantedAt: _parseOptionalDate(map['reward_granted_at']),
        rewardTransactionId: map['reward_transaction_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  UnlockedAchievementEntity _unlockedAchievementFromMap(
    Map<String, dynamic> map,
  ) => UnlockedAchievementEntity(
    id: map['unlocked_achievement_id'] as String,
    code: map['achievement_code'] as String,
    name: map['achievement_name'] as String,
    rewardType: _parseRewardType(map['unlocked_reward_type'] as String),
    rewardAmount: (map['unlocked_reward_amount'] as num?)?.toInt() ?? 0,
  );

  DateTime? _parseOptionalDate(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;

  AchievementCategory _parseCategory(String value) => switch (value) {
    'streak' => AchievementCategory.streak,
    'social' => AchievementCategory.social,
    'milestone' => AchievementCategory.milestone,
    _ => AchievementCategory.workout,
  };

  AchievementCriteria _parseCriteria(String value) => switch (value) {
    'current_streak' => AchievementCriteria.currentStreak,
    'leaderboard_join' => AchievementCriteria.leaderboardJoin,
    'weekly_leaderboard_win' => AchievementCriteria.weeklyLeaderboardWin,
    _ => AchievementCriteria.qualifyingWorkoutCount,
  };

  RewardType _parseRewardType(String value) => switch (value) {
    'points' => RewardType.points,
    'screen_time' => RewardType.screenTime,
    _ => RewardType.recognition,
  };
}
