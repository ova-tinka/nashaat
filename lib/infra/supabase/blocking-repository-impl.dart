import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/entities/blocking-rule-entity.dart';
import '../../core/entities/enums.dart';
import '../../core/repositories/blocking-repository.dart';
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
    return (data as List).map(_fromMap).toList();
  }

  @override
  Future<BlockingRuleEntity> createRule(BlockingRuleEntity rule) async {
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
    return _fromMap(data);
  }

  @override
  Future<BlockingRuleEntity> updateRuleStatus(
    String id,
    RuleStatus status,
  ) async {
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
    await _db.from('blocking_rules').delete().eq('id', id);
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
