import '../../core/entities/blocking-rule-entity.dart';
import '../../core/entities/enums.dart';
import '../../core/repositories/blocking-repository.dart';
import '../../shared/logger.dart';
import 'supabase-client.dart';

class SupabaseBlockingRepository implements BlockingRepository {
  final _db = SupabaseClientProvider.client;

  @override
  Future<List<BlockingRuleEntity>> getUserRules(
    String userId, {
    RuleStatus? status,
  }) async {
    var query = _db
        .from('blocking_rules')
        .select()
        .eq('user_id', userId)
        .eq('item_type', 'app'); // UC-08 is app-only

    if (status != null) {
      query = query.eq('status', _statusToString(status));
    }

    final data = await query.order('created_at', ascending: true);
    final rules = (data as List)
        .map((e) => _fromMap(e as Map<String, dynamic>))
        .toList();
    Log.db('loaded ${rules.length} blocking rule(s) for user ${userId.substring(0, 8)}…');
    return rules;
  }

  @override
  Future<BlockingRuleEntity> createRule(BlockingRuleEntity rule) async {
    Log.blocking('+1 rule: ${rule.itemIdentifier}');
    final data = await _db
        .from('blocking_rules')
        .insert({
          'user_id': rule.userId,
          'item_type': 'app',
          'item_identifier': rule.itemIdentifier,
          'status': _statusToString(rule.status),
        })
        .select()
        .single();
    final created = _fromMap(data);
    Log.blocking('rule created ✓ id ${created.id.substring(0, 8)}…');
    return created;
  }

  @override
  Future<BlockingRuleEntity> updateRuleStatus(
    String id,
    RuleStatus status,
  ) async {
    Log.blocking('rule ${id.substring(0, 8)}… → ${_statusToString(status)}');
    final data = await _db
        .from('blocking_rules')
        .update({
          'status': _statusToString(status),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return _fromMap(data);
  }

  @override
  Future<void> deleteRule(String id) async {
    Log.blocking('deleting rule ${id.substring(0, 8)}…');
    await _db.from('blocking_rules').delete().eq('id', id);
    Log.blocking('rule deleted ✓');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  BlockingRuleEntity _fromMap(Map<String, dynamic> map) => BlockingRuleEntity(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        itemType: ItemType.app,
        itemIdentifier: map['item_identifier'] as String,
        status: _parseStatus(map['status'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  String _statusToString(RuleStatus s) => switch (s) {
        RuleStatus.active => 'active',
        RuleStatus.inactive => 'inactive',
        RuleStatus.archived => 'archived',
      };

  RuleStatus _parseStatus(String s) => switch (s) {
        'active' => RuleStatus.active,
        'inactive' => RuleStatus.inactive,
        _ => RuleStatus.archived,
      };
}
