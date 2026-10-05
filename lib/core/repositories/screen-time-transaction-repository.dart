import '../entities/screen-time-transaction-entity.dart';

class ScreenTimeBalanceResult {
  final int balanceMinutes;
  final int minutesChanged;

  const ScreenTimeBalanceResult({
    required this.balanceMinutes,
    required this.minutesChanged,
  });
}

abstract class ScreenTimeTransactionRepository {
  Future<List<ScreenTimeTransactionEntity>> getUserTransactions(
    String userId, {
    int? limit,
  });

  Future<ScreenTimeBalanceResult> creditWeeklyFreeMinutes();

  Future<ScreenTimeBalanceResult> consumeMinute();
}
