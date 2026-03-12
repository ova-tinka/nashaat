import 'enums.dart';

class NotificationEntity {
  final String id;
  final String userId;
  final String title;
  final String body;
  /// e.g. 'workout_reminder', 'goal_deadline', 'friend_request'
  final String? type;
  final NotificationStatus status;
  final DateTime createdAt;

  const NotificationEntity({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type,
    this.status = NotificationStatus.unread,
    required this.createdAt,
  });

  NotificationEntity copyWith({NotificationStatus? status}) {
    return NotificationEntity(
      id: id,
      userId: userId,
      title: title,
      body: body,
      type: type,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
