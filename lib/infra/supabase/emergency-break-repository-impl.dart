import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/entities/emergency-break-entity.dart';
import '../../core/repositories/emergency-break-repository.dart';

class SupabaseEmergencyBreakRepository implements EmergencyBreakRepository {
  final _db = Supabase.instance.client;

  @override
  Future<List<EmergencyBreakEntity>> getUserBreaks(String userId) async {
    final data = await _db
        .from('emergency_breaks')
        .select()
        .eq('user_id', userId)
        .order('granted_at', ascending: false);
    return (data as List)
        .map((e) => _fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<EmergencyBreakEntity> requestBreak(
    String userId,
    int durationMinutes, {
    String? reason,
  }) async {
    final data = await _db.from('emergency_breaks').insert({
      'user_id': userId,
      'duration_minutes': durationMinutes,
      'reason': reason,
      'granted_at': DateTime.now().toIso8601String(),
    }).select().single();
    return _fromMap(data);
  }

  EmergencyBreakEntity _fromMap(Map<String, dynamic> m) => EmergencyBreakEntity(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        durationMinutes: m['duration_minutes'] as int,
        reason: m['reason'] as String?,
        grantedAt: DateTime.parse(m['granted_at'] as String),
      );
}
