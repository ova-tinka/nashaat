class EmergencyBreakEntity {
  final String id;
  final String userId;
  final int durationMinutes;
  final String? reason;
  final DateTime grantedAt;

  const EmergencyBreakEntity({
    required this.id,
    required this.userId,
    required this.durationMinutes,
    this.reason,
    required this.grantedAt,
  });
}
