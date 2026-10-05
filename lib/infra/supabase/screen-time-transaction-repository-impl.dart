import '../../core/entities/enums.dart';
import '../../core/entities/screen-time-transaction-entity.dart';
import '../../core/repositories/screen-time-transaction-repository.dart';
import '../../shared/logger.dart';
import 'supabase-client.dart';

class SupabaseScreenTimeTransactionRepository
    implements ScreenTimeTransactionRepository {
  final _db = SupabaseClientProvider.client;

  @override
  Future<List<ScreenTimeTransactionEntity>> getUserTransactions(
    String userId, {
    int? limit,
  }) async {
    var query = _db
        .from('screen_time_transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    if (limit != null) {
      query = query.limit(limit);
    }

    final data = await query;
    final txns = (data as List)
        .map((e) => _fromMap(e as Map<String, dynamic>))
        .toList();
    Log.db('loaded ${txns.length} screen-time transaction(s)');
    return txns;
  }

  @override
  Future<ScreenTimeBalanceResult> creditWeeklyFreeMinutes() async {
    final data = await _db.rpc('credit_weekly_free_screen_time');
    return _balanceResult(data);
  }

  @override
  Future<ScreenTimeBalanceResult> consumeMinute() async {
    final data = await _db.rpc('consume_screen_time_minute');
    return _balanceResult(data);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  ScreenTimeTransactionEntity _fromMap(Map<String, dynamic> map) =>
      ScreenTimeTransactionEntity(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        amountMinutes: map['amount_minutes'] as int,
        transactionType: _parseType(
          map['transaction_type'] as String? ?? 'earned',
        ),
        description: map['description'] as String?,
        referenceId: map['reference_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  TransactionType _parseType(String s) => switch (s) {
    'spent' => TransactionType.spent,
    'penalty' => TransactionType.penalty,
    'manual_adjustment' => TransactionType.manualAdjustment,
    _ => TransactionType.earned,
  };

  ScreenTimeBalanceResult _balanceResult(dynamic data) {
    final row = data is List && data.isNotEmpty
        ? data.first as Map<String, dynamic>
        : data as Map<String, dynamic>;
    return ScreenTimeBalanceResult(
      balanceMinutes: (row['balance_minutes'] as num?)?.toInt() ?? 0,
      minutesChanged: (row['minutes_changed'] as num?)?.toInt() ?? 0,
    );
  }
}
