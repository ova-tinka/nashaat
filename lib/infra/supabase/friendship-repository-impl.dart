import '../../core/entities/enums.dart';
import '../../core/entities/friendship-entity.dart';
import '../../core/repositories/friendship-repository.dart';
import '../../shared/logger.dart';
import 'supabase-client.dart';

class SupabaseFriendshipRepository implements FriendshipRepository {
  final _db = SupabaseClientProvider.client;

  @override
  Future<List<FriendshipEntity>> getFriends(String userId) async {
    final data = await _db
        .from('friendships')
        .select()
        .eq('status', 'accepted')
        .or('requester_id.eq.$userId,addressee_id.eq.$userId');
    return (data as List)
        .map((e) => _fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<FriendshipEntity>> getPendingRequests(String userId) async {
    final data = await _db
        .from('friendships')
        .select()
        .eq('addressee_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => _fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<FriendshipEntity> sendRequest(
      String requesterId, String addresseeId) async {
    Log.db('friend request: $requesterId → $addresseeId');
    final data = await _db
        .from('friendships')
        .insert({
          'requester_id': requesterId,
          'addressee_id': addresseeId,
          'status': 'pending',
        })
        .select()
        .single();
    return _fromMap(data);
  }

  @override
  Future<FriendshipEntity> updateStatus(
    String friendshipId,
    FriendshipStatus status,
  ) async {
    final data = await _db
        .from('friendships')
        .update({
          'status': _statusToString(status),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', friendshipId)
        .select()
        .single();
    return _fromMap(data);
  }

  @override
  Future<void> removeFriend(String friendshipId) async {
    await _db.from('friendships').delete().eq('id', friendshipId);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  FriendshipEntity _fromMap(Map<String, dynamic> map) => FriendshipEntity(
        id: map['id'] as String,
        requesterId: map['requester_id'] as String,
        addresseeId: map['addressee_id'] as String,
        status: _parseStatus(map['status'] as String? ?? 'pending'),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  FriendshipStatus _parseStatus(String s) => switch (s) {
        'accepted' => FriendshipStatus.accepted,
        'rejected' => FriendshipStatus.rejected,
        _ => FriendshipStatus.pending,
      };

  String _statusToString(FriendshipStatus s) => switch (s) {
        FriendshipStatus.pending => 'pending',
        FriendshipStatus.accepted => 'accepted',
        FriendshipStatus.rejected => 'rejected',
      };
}
