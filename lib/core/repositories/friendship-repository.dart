import '../entities/enums.dart';
import '../entities/friendship-entity.dart';

abstract class FriendshipRepository {
  /// Returns all accepted friendships for the given user.
  Future<List<FriendshipEntity>> getFriends(String userId);

  /// Returns incoming pending requests addressed to the given user.
  Future<List<FriendshipEntity>> getPendingRequests(String userId);

  Future<FriendshipEntity> sendRequest(String requesterId, String addresseeId);

  Future<FriendshipEntity> updateStatus(
    String friendshipId,
    FriendshipStatus status,
  );

  Future<void> removeFriend(String friendshipId);
}
