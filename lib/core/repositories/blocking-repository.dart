import '../entities/blocking-rule-entity.dart';
import '../entities/enums.dart';

abstract class BlockingRepository {
  Future<List<BlockingRuleEntity>> getUserRules(
    String userId, {
    RuleStatus? status,
  });

  Future<BlockingRuleEntity> createRule(BlockingRuleEntity rule);

  Future<BlockingRuleEntity> updateRuleStatus(String id, RuleStatus status);

  Future<void> deleteRule(String id);
}
