import 'enums.dart';

class ScreenTimeTransactionEntity {
  final String id;
  final String userId;
  /// Positive = earned, negative = spent / penalty
  final int amountMinutes;
  final TransactionType transactionType;
  final String? description;
  /// Optional reference to workout_logs.id or emergency_breaks.id
  final String? referenceId;
  final DateTime createdAt;

  const ScreenTimeTransactionEntity({
    required this.id,
    required this.userId,
    required this.amountMinutes,
    required this.transactionType,
    this.description,
    this.referenceId,
    required this.createdAt,
  });
}
