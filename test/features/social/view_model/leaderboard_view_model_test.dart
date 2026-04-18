import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/features/social/view-model/leaderboard-view-model.dart';

import '../../../helpers/mock_repositories.dart';
import '../../../helpers/test_data.dart';

void main() {
  late MockLeaderboardRepository mockLeaderboardRepo;
  late MockProfileRepository mockProfileRepo;
  late LeaderboardViewModel vm;

  setUp(() {
    mockLeaderboardRepo = MockLeaderboardRepository();
    mockProfileRepo = MockProfileRepository();
    vm = LeaderboardViewModel(
      leaderboardRepo: mockLeaderboardRepo,
      profileRepo: mockProfileRepo,
      getUserId: () => 'u1',
    );
  });

  tearDown(() => vm.dispose());

  // ── Initial state ──────────────────────────────────────────────────────────

  group('initial state', () {
    test('leaderboards is empty', () {
      expect(vm.leaderboards, isEmpty);
    });

    test('rankings is empty', () {
      expect(vm.rankings, isEmpty);
    });

    test('isLoading is false', () {
      expect(vm.isLoading, isFalse);
    });
  });

  // ── load ───────────────────────────────────────────────────────────────────

  group('load', () {
    test('success: leaderboards populated, selectedLeaderboard=first, rankings loaded',
        () async {
      final lb = TestData.leaderboard();
      final member = TestData.leaderboardMember(userId: 'u1');
      when(() => mockLeaderboardRepo.getUserLeaderboards(any()))
          .thenAnswer((_) async => [lb]);
      when(() => mockLeaderboardRepo.getMembers(any()))
          .thenAnswer((_) async => [member]);
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());

      await vm.load();

      expect(vm.leaderboards.length, 1);
      expect(vm.selectedLeaderboard?.id, 'lb1');
      expect(vm.rankings.length, 1);
    });

    test('failure: error set', () async {
      when(() => mockLeaderboardRepo.getUserLeaderboards(any()))
          .thenThrow(Exception('load failed'));

      await vm.load();

      expect(vm.error, isNotNull);
    });
  });

  // ── selectLeaderboard ──────────────────────────────────────────────────────

  group('selectLeaderboard', () {
    test('changes selectedLeaderboard and reloads rankings', () async {
      final lb2 = TestData.leaderboard(id: 'lb2', name: 'Team Beta');
      final member = TestData.leaderboardMember(leaderboardId: 'lb2');

      when(() => mockLeaderboardRepo.getMembers('lb2'))
          .thenAnswer((_) async => [member]);
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());

      await vm.selectLeaderboard(lb2);

      expect(vm.selectedLeaderboard?.id, 'lb2');
      expect(vm.rankings.length, 1);
    });
  });

  // ── myRank ─────────────────────────────────────────────────────────────────

  group('myRank', () {
    test('returns 0 when user not in rankings', () async {
      final lb = TestData.leaderboard();
      final otherMember =
          TestData.leaderboardMember(userId: 'other-user', weeklyScore: 200);
      when(() => mockLeaderboardRepo.getUserLeaderboards(any()))
          .thenAnswer((_) async => [lb]);
      when(() => mockLeaderboardRepo.getMembers(any()))
          .thenAnswer((_) async => [otherMember]);
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());

      await vm.load();

      expect(vm.myRank, 0);
    });

    test('returns correct rank when user is in rankings', () async {
      final lb = TestData.leaderboard();
      // u1 is second with lower score (members sorted by repo; just ensure rank calculation)
      final memberA =
          TestData.leaderboardMember(userId: 'user-a', weeklyScore: 300);
      final memberB =
          TestData.leaderboardMember(userId: 'u1', weeklyScore: 100);
      when(() => mockLeaderboardRepo.getUserLeaderboards(any()))
          .thenAnswer((_) async => [lb]);
      when(() => mockLeaderboardRepo.getMembers(any()))
          .thenAnswer((_) async => [memberA, memberB]);
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());

      await vm.load();

      expect(vm.myRank, 2);
    });
  });

  // ── createLeaderboard ──────────────────────────────────────────────────────

  group('createLeaderboard', () {
    test('success: leaderboard added to list, selectedLeaderboard updated',
        () async {
      final newLb = TestData.leaderboard(id: 'lb-new', name: 'My Squad');
      when(() => mockLeaderboardRepo.createLeaderboard(any(), any(), any()))
          .thenAnswer((_) async => newLb);

      await vm.createLeaderboard('My Squad');

      expect(vm.leaderboards.length, 1);
      expect(vm.leaderboards.first.id, 'lb-new');
      expect(vm.selectedLeaderboard?.id, 'lb-new');
    });

    test('failure: error set', () async {
      when(() => mockLeaderboardRepo.createLeaderboard(any(), any(), any()))
          .thenThrow(Exception('create failed'));

      await vm.createLeaderboard('My Squad');

      expect(vm.error, isNotNull);
    });
  });

  // ── joinByInviteCode ───────────────────────────────────────────────────────

  group('joinByInviteCode', () {
    test('success: leaderboard added', () async {
      final lb = TestData.leaderboard(id: 'lb-join');
      when(() => mockLeaderboardRepo.getLeaderboardByInviteCode(any()))
          .thenAnswer((_) async => lb);
      when(() => mockLeaderboardRepo.joinLeaderboard(any(), any()))
          .thenAnswer((_) async => TestData.leaderboardMember());
      when(() => mockLeaderboardRepo.getMembers(any()))
          .thenAnswer((_) async => [TestData.leaderboardMember()]);
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());

      await vm.joinByInviteCode('ABC123');

      expect(vm.leaderboards, contains(lb));
    });

    test('invite code not found: error set', () async {
      when(() => mockLeaderboardRepo.getLeaderboardByInviteCode(any()))
          .thenAnswer((_) async => null);

      await vm.joinByInviteCode('INVALID');

      expect(vm.error, contains('not found'));
    });
  });

  // ── clearError ─────────────────────────────────────────────────────────────

  group('clearError', () {
    test('clears the error', () async {
      when(() => mockLeaderboardRepo.getLeaderboardByInviteCode(any()))
          .thenAnswer((_) async => null);
      await vm.joinByInviteCode('INVALID');
      expect(vm.error, isNotNull);

      vm.clearError();

      expect(vm.error, isNull);
    });
  });
}
