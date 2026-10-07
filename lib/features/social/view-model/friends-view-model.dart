import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/friendship-entity.dart';
import '../../../core/entities/public-profile-entity.dart';
import '../../../core/repositories/friendship-repository.dart';
import '../../../core/repositories/profile-repository.dart';
import '../../../shared/logger.dart';

enum FriendRelationship { none, outgoingPending, incomingPending, friends }

class FriendProfile {
  final PublicProfileEntity profile;
  final FriendshipEntity? friendship;
  final FriendRelationship relationship;

  const FriendProfile({
    required this.profile,
    required this.relationship,
    this.friendship,
  });

  String get displayName =>
      profile.username ?? profile.firstName ?? profile.lastName ?? 'Athlete';
}

class FriendsViewModel extends ChangeNotifier {
  final FriendshipRepository _friendshipRepo;
  final ProfileRepository _profileRepo;
  final String Function() _getUserId;

  FriendsViewModel({
    required FriendshipRepository friendshipRepo,
    required ProfileRepository profileRepo,
    String Function()? getUserId,
  }) : _friendshipRepo = friendshipRepo,
       _profileRepo = profileRepo,
       _getUserId =
           getUserId ??
           (() => Supabase.instance.client.auth.currentUser?.id ?? '');

  List<FriendProfile> _friends = [];
  List<FriendProfile> _incomingRequests = [];
  List<FriendProfile> _sentRequests = [];
  List<FriendProfile> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isMutating = false;
  String? _error;

  List<FriendProfile> get friends => List.unmodifiable(_friends);
  List<FriendProfile> get incomingRequests =>
      List.unmodifiable(_incomingRequests);
  List<FriendProfile> get sentRequests => List.unmodifiable(_sentRequests);
  List<FriendProfile> get searchResults => List.unmodifiable(_searchResults);
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  bool get isMutating => _isMutating;
  String? get error => _error;
  String get currentUserId => _getUserId();

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _friendshipRepo.getFriends(currentUserId),
        _friendshipRepo.getPendingRequests(currentUserId),
        _friendshipRepo.getSentRequests(currentUserId),
      ]);
      _friends = await _withProfiles(results[0], FriendRelationship.friends);
      _incomingRequests = await _withProfiles(
        results[1],
        FriendRelationship.incomingPending,
      );
      _sentRequests = await _withProfiles(
        results[2],
        FriendRelationship.outgoingPending,
      );
    } catch (error) {
      Log.error('FriendsViewModel.load', error);
      _error = 'Could not load friends.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    _isSearching = true;
    _error = null;
    notifyListeners();
    try {
      final profiles = await _profileRepo.searchPublicProfiles(normalizedQuery);
      _searchResults = profiles.map(_asSearchResult).toList(growable: false);
    } catch (error) {
      Log.error('FriendsViewModel.search', error);
      _error = 'Could not search for athletes.';
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> sendRequest(FriendProfile person) async {
    if (person.relationship != FriendRelationship.none || _isMutating) return;
    await _mutate(() async {
      final friendship = await _friendshipRepo.sendRequest(
        currentUserId,
        person.profile.id,
      );
      _searchResults = _searchResults
          .map(
            (result) => result.profile.id == person.profile.id
                ? FriendProfile(
                    profile: result.profile,
                    friendship: friendship,
                    relationship: FriendRelationship.outgoingPending,
                  )
                : result,
          )
          .toList(growable: false);
      await load();
    });
  }

  Future<void> acceptRequest(FriendProfile person) => _updateRequest(
    person,
    FriendshipStatus.accepted,
    failure: 'Could not accept this request.',
  );

  Future<void> declineRequest(FriendProfile person) => _updateRequest(
    person,
    FriendshipStatus.rejected,
    failure: 'Could not decline this request.',
  );

  Future<void> removeFriend(FriendProfile person) async {
    final friendship = person.friendship;
    if (friendship == null || _isMutating) return;
    await _mutate(() async {
      await _friendshipRepo.removeFriend(friendship.id);
      await load();
    }, failure: 'Could not remove this friend.');
  }

  Future<void> _updateRequest(
    FriendProfile person,
    FriendshipStatus status, {
    required String failure,
  }) async {
    final friendship = person.friendship;
    if (friendship == null || _isMutating) return;
    await _mutate(() async {
      await _friendshipRepo.updateStatus(friendship.id, status);
      await load();
    }, failure: failure);
  }

  Future<void> _mutate(
    Future<void> Function() action, {
    String? failure,
  }) async {
    _isMutating = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      Log.error('FriendsViewModel.mutate', error);
      _error = failure ?? 'Could not update this friendship.';
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<List<FriendProfile>> _withProfiles(
    List<FriendshipEntity> friendships,
    FriendRelationship relationship,
  ) async {
    final profiles = await Future.wait(
      friendships.map((friendship) {
        final otherUserId = friendship.requesterId == currentUserId
            ? friendship.addresseeId
            : friendship.requesterId;
        return _profileRepo.getPublicProfile(otherUserId);
      }),
    );
    return [
      for (var index = 0; index < friendships.length; index++)
        if (profiles[index] != null)
          FriendProfile(
            profile: profiles[index]!,
            friendship: friendships[index],
            relationship: relationship,
          ),
    ];
  }

  FriendProfile _asSearchResult(PublicProfileEntity profile) {
    for (final person in _friends) {
      if (person.profile.id == profile.id) return person;
    }
    for (final person in _incomingRequests) {
      if (person.profile.id == profile.id) return person;
    }
    for (final person in _sentRequests) {
      if (person.profile.id == profile.id) return person;
    }
    return FriendProfile(
      profile: profile,
      relationship: FriendRelationship.none,
    );
  }
}
