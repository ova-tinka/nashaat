import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/core/entities/enums.dart';
import 'package:nashaat/core/entities/friendship-entity.dart';
import 'package:nashaat/features/social/view-model/friends-view-model.dart';

import '../../../helpers/mock_repositories.dart';
import '../../../helpers/test_data.dart';

void main() {
  late MockFriendshipRepository friendshipRepo;
  late MockProfileRepository profileRepo;
  late FriendsViewModel vm;

  FriendshipEntity friendship({
    String id = 'friendship-1',
    String requesterId = 'u1',
    String addresseeId = 'u2',
    FriendshipStatus status = FriendshipStatus.accepted,
  }) => FriendshipEntity(
    id: id,
    requesterId: requesterId,
    addresseeId: addresseeId,
    status: status,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    friendshipRepo = MockFriendshipRepository();
    profileRepo = MockProfileRepository();
    vm = FriendsViewModel(
      friendshipRepo: friendshipRepo,
      profileRepo: profileRepo,
      getUserId: () => 'u1',
    );
  });

  tearDown(() => vm.dispose());

  void stubEmptyLoad() {
    when(() => friendshipRepo.getFriends('u1')).thenAnswer((_) async => []);
    when(
      () => friendshipRepo.getPendingRequests('u1'),
    ).thenAnswer((_) async => []);
    when(
      () => friendshipRepo.getSentRequests('u1'),
    ).thenAnswer((_) async => []);
  }

  test(
    'load resolves the other profile for each accepted friendship',
    () async {
      when(
        () => friendshipRepo.getFriends('u1'),
      ).thenAnswer((_) async => [friendship()]);
      when(
        () => friendshipRepo.getPendingRequests('u1'),
      ).thenAnswer((_) async => []);
      when(
        () => friendshipRepo.getSentRequests('u1'),
      ).thenAnswer((_) async => []);
      when(() => profileRepo.getPublicProfile('u2')).thenAnswer(
        (_) async => TestData.publicProfile(id: 'u2', username: 'sarah'),
      );

      await vm.load();

      expect(vm.friends.single.displayName, 'sarah');
      expect(vm.friends.single.relationship, FriendRelationship.friends);
    },
  );

  test(
    'search labels an incoming request instead of allowing a duplicate send',
    () async {
      final request = friendship(
        requesterId: 'u2',
        addresseeId: 'u1',
        status: FriendshipStatus.pending,
      );
      when(() => friendshipRepo.getFriends('u1')).thenAnswer((_) async => []);
      when(
        () => friendshipRepo.getPendingRequests('u1'),
      ).thenAnswer((_) async => [request]);
      when(
        () => friendshipRepo.getSentRequests('u1'),
      ).thenAnswer((_) async => []);
      when(() => profileRepo.getPublicProfile('u2')).thenAnswer(
        (_) async => TestData.publicProfile(id: 'u2', username: 'sarah'),
      );
      when(() => profileRepo.searchPublicProfiles('sarah')).thenAnswer(
        (_) async => [TestData.publicProfile(id: 'u2', username: 'sarah')],
      );

      await vm.load();
      await vm.search('sarah');

      expect(
        vm.searchResults.single.relationship,
        FriendRelationship.incomingPending,
      );
    },
  );

  test('accept request updates the relationship and reloads state', () async {
    final request = friendship(
      requesterId: 'u2',
      addresseeId: 'u1',
      status: FriendshipStatus.pending,
    );
    when(() => friendshipRepo.getFriends('u1')).thenAnswer((_) async => []);
    when(
      () => friendshipRepo.getPendingRequests('u1'),
    ).thenAnswer((_) async => [request]);
    when(
      () => friendshipRepo.getSentRequests('u1'),
    ).thenAnswer((_) async => []);
    when(
      () => profileRepo.getPublicProfile('u2'),
    ).thenAnswer((_) async => TestData.publicProfile(id: 'u2'));
    await vm.load();
    when(
      () => friendshipRepo.updateStatus(
        'friendship-1',
        FriendshipStatus.accepted,
      ),
    ).thenAnswer(
      (_) async => request.copyWith(status: FriendshipStatus.accepted),
    );

    await vm.acceptRequest(vm.incomingRequests.single);

    verify(
      () => friendshipRepo.updateStatus(
        'friendship-1',
        FriendshipStatus.accepted,
      ),
    ).called(1);
  });

  test('send request rejects no-op relationship changes', () async {
    stubEmptyLoad();
    await vm.load();
    final person = FriendProfile(
      profile: TestData.publicProfile(id: 'u2'),
      relationship: FriendRelationship.none,
    );
    when(
      () => friendshipRepo.sendRequest('u1', 'u2'),
    ).thenAnswer((_) async => friendship(status: FriendshipStatus.pending));

    await vm.sendRequest(person);

    verify(() => friendshipRepo.sendRequest('u1', 'u2')).called(1);
  });
}
