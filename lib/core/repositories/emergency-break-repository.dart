import '../entities/emergency-break-entity.dart';

abstract class EmergencyBreakRepository {
  Future<List<EmergencyBreakEntity>> getUserBreaks(String userId);

  Future<EmergencyBreakEntity> requestBreak(
    String userId,
    int durationMinutes, {
    String? reason,
  });
}
