import '../../core/entities/enums.dart';
import '../../core/entities/notification-entity.dart';
import '../../core/repositories/notification-repository.dart';
import '../../shared/logger.dart';
import 'supabase-client.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  final _db = SupabaseClientProvider.client;

  @override
  Future<List<NotificationEntity>> getUserNotifications(
    String userId, {
    NotificationStatus? status,
  }) async {
    var query = _db
        .from('notifications')
        .select()
        .eq('user_id', userId);

    if (status != null) {
      query = query.eq('status', _statusToString(status));
    }

    final data = await query.order('created_at', ascending: false);
    return (data as List)
        .map((e) => _fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<NotificationEntity> markAsRead(String id) async {
    Log.db('marking notification read: $id');
    final data = await _db
        .from('notifications')
        .update({'status': 'read'})
        .eq('id', id)
        .select()
        .single();
    return _fromMap(data);
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    Log.db('marking all notifications read for user: $userId');
    await _db
        .from('notifications')
        .update({'status': 'read'})
        .eq('user_id', userId)
        .eq('status', 'unread');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  NotificationEntity _fromMap(Map<String, dynamic> map) => NotificationEntity(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        title: map['title'] as String,
        body: map['body'] as String,
        type: map['type'] as String?,
        status: _parseStatus(map['status'] as String? ?? 'unread'),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  NotificationStatus _parseStatus(String s) => switch (s) {
        'read' => NotificationStatus.read,
        'archived' => NotificationStatus.archived,
        _ => NotificationStatus.unread,
      };

  String _statusToString(NotificationStatus s) => switch (s) {
        NotificationStatus.unread => 'unread',
        NotificationStatus.read => 'read',
        NotificationStatus.archived => 'archived',
      };
}
