import '../entities/user-reward-entity.dart';

abstract class UserRewardRepository {
  Future<List<UserRewardEntity>> getUserRewards(String userId);

  Future<UserRewardEntity> addReward(
    String userId,
    String title, {
    String? description,
  });
}
