import '../entities/app-usage-insight-entity.dart';

abstract class AppUsageInsightRepository {
  Future<AppUsageInsightEntity?> getInsight(String userId, DateTime date);

  Future<List<AppUsageInsightEntity>> getInsights(
    String userId, {
    DateTime? from,
    DateTime? to,
  });

  Future<AppUsageInsightEntity> upsertInsight(AppUsageInsightEntity insight);
}
