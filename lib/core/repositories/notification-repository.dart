import '../entities/enums.dart';
import '../entities/notification-entity.dart';

abstract class NotificationRepository {
  Future<List<NotificationEntity>> getUserNotifications(
    String userId, {
    NotificationStatus? status,
  });

  Future<NotificationEntity> markAsRead(String id);

  Future<void> markAllAsRead(String userId);
}
