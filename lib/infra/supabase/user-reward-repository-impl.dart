import '../../core/entities/user-reward-entity.dart';
import '../../core/repositories/user-reward-repository.dart';
import '../../shared/logger.dart';
import 'supabase-client.dart';

class SupabaseUserRewardRepository implements UserRewardRepository {
  final _db = SupabaseClientProvider.client;

  @override
  Future<List<UserRewardEntity>> getUserRewards(String userId) async {
    final data = await _db
        .from('user_rewards')
        .select()
        .eq('user_id', userId)
        .order('unlocked_at', ascending: false);
    return (data as List)
        .map((e) => _fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<UserRewardEntity> addReward(
    String userId,
    String title, {
    String? description,
  }) async {
    Log.db('adding reward "$title" for user: $userId');
    final data = await _db
        .from('user_rewards')
        .insert({
          'user_id': userId,
          'reward_title': title,
          'reward_description': ?description,
        })
        .select()
        .single();
    return _fromMap(data);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  UserRewardEntity _fromMap(Map<String, dynamic> map) => UserRewardEntity(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        rewardTitle: map['reward_title'] as String,
        rewardDescription: map['reward_description'] as String?,
        unlockedAt: DateTime.parse(map['unlocked_at'] as String),
      );
}
