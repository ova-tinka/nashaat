import 'enums.dart';

class FriendshipEntity {
  final String id;
  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FriendshipEntity({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    this.status = FriendshipStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  FriendshipEntity copyWith({FriendshipStatus? status, DateTime? updatedAt}) {
    return FriendshipEntity(
      id: id,
      requesterId: requesterId,
      addresseeId: addresseeId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
