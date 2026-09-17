import '../entities/achievement-entity.dart';

abstract class AchievementRepository {
  Future<List<UnlockedAchievementEntity>> evaluateUserAchievements();

  Future<List<AchievementDefinitionEntity>> getDefinitions({
    bool activeOnly = true,
  });

  Future<List<UserAchievementEntity>> getUserAchievements(String userId);
}
