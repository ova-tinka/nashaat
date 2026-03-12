import '../entities/screen-time-transaction-entity.dart';

abstract class ScreenTimeTransactionRepository {
  Future<List<ScreenTimeTransactionEntity>> getUserTransactions(
    String userId, {
    int? limit,
  });

  Future<ScreenTimeTransactionEntity> recordTransaction(
    ScreenTimeTransactionEntity transaction,
  );
}
