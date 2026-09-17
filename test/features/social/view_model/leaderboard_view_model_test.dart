import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/core/entities/achievement-entity.dart';
import 'package:nashaat/core/entities/enums.dart';
import 'package:nashaat/features/social/view-model/leaderboard-view-model.dart';

import '../../../helpers/mock_repositories.dart';
import '../../../helpers/test_data.dart';

void main() {
  late MockLeaderboardRepository mockLeaderboardRepo;
  late MockProfileRepository mockProfileRepo;
  late MockAchievementRepository mockAchievementRepo;
  late LeaderboardViewModel vm;

  setUp(() {
    mockLeaderboardRepo = MockLeaderboardRepository();
    when(() => mockLeaderboardRepo.recalculateMyWeeklyScore())
        .thenAnswer((_) async {});
    mockProfileRepo = MockProfileRepository();
    mockAchievementRepo = MockAchievementRepository();
    vm = LeaderboardViewModel(
      leaderboardRepo: mockLeaderboardRepo,
      profileRepo: mockProfileRepo,
      achievementRepo: mockAchievementRepo,
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
    test(
      'success: leaderboards populated, selectedLeaderboard=first, rankings loaded',
      () async {
        final lb = TestData.leaderboard();
        final member = TestData.leaderboardMember(userId: 'u1');
        when(
          () => mockLeaderboardRepo.getUserLeaderboards(any()),
        ).thenAnswer((_) async => [lb]);
        when(
          () => mockLeaderboardRepo.getMembers(any()),
        ).thenAnswer((_) async => [member]);
        when(
          () => mockProfileRepo.getProfile(any()),
        ).thenAnswer((_) async => TestData.profile());

        await vm.load();

        expect(vm.leaderboards.length, 1);
        expect(vm.selectedLeaderboard?.id, 'lb1');
        expect(vm.rankings.length, 1);
        verifyInOrder([
          () => mockLeaderboardRepo.getUserLeaderboards('u1'),
          () => mockLeaderboardRepo.recalculateMyWeeklyScore(),
          () => mockLeaderboardRepo.getMembers('lb1'),
        ]);
      },
    );

    test('failure: error set', () async {
      when(
        () => mockLeaderboardRepo.getUserLeaderboards(any()),
      ).thenThrow(Exception('load failed'));

      await vm.load();

      expect(vm.error, isNotNull);
    });

    test('reload refreshes rankings for the selected board', () async {
      final lb = TestData.leaderboard();
      var score = 10;
      when(
        () => mockLeaderboardRepo.getUserLeaderboards(any()),
      ).thenAnswer((_) async => [lb]);
      when(() => mockLeaderboardRepo.getMembers(lb.id)).thenAnswer(
        (_) async => [TestData.leaderboardMember(weeklyScore: score)],
      );
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => TestData.profile());

      await vm.load();
      score = 25;
      await vm.load();

      expect(vm.rankings.single.weeklyScore, 25);
      verify(() => mockLeaderboardRepo.getMembers(lb.id)).called(2);
    });

    test(
      'ranks members by weekly score even if rows arrive unsorted',
      () async {
        final lb = TestData.leaderboard();
        when(
          () => mockLeaderboardRepo.getUserLeaderboards(any()),
        ).thenAnswer((_) async => [lb]);
        when(() => mockLeaderboardRepo.getMembers(lb.id)).thenAnswer(
          (_) async => [
            TestData.leaderboardMember(userId: 'u1', weeklyScore: 30),
            TestData.leaderboardMember(userId: 'u2', weeklyScore: 90),
            TestData.leaderboardMember(userId: 'u3', weeklyScore: 50),
          ],
        );
        when(
          () => mockProfileRepo.getProfile(any()),
        ).thenAnswer((_) async => TestData.profile());

        await vm.load();

        expect(vm.rankings.map((entry) => entry.userId), ['u2', 'u3', 'u1']);
        expect(vm.rankings.map((entry) => entry.rank), [1, 2, 3]);
        expect(vm.myRank, 3);
      },
    );
  });

  // ── selectLeaderboard ──────────────────────────────────────────────────────

  group('selectLeaderboard', () {
    test('changes selectedLeaderboard and reloads rankings', () async {
      final lb2 = TestData.leaderboard(id: 'lb2', name: 'Team Beta');
      final member = TestData.leaderboardMember(leaderboardId: 'lb2');

      when(
        () => mockLeaderboardRepo.getMembers('lb2'),
      ).thenAnswer((_) async => [member]);
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => TestData.profile());
      await vm.selectLeaderboard(lb2);

      expect(vm.selectedLeaderboard?.id, 'lb2');
      expect(vm.rankings.length, 1);
    });
  });

  // ── myRank ─────────────────────────────────────────────────────────────────

  group('myRank', () {
    test('returns 0 when user not in rankings', () async {
      final lb = TestData.leaderboard();
      final otherMember = TestData.leaderboardMember(
        userId: 'other-user',
        weeklyScore: 200,
      );
      when(
        () => mockLeaderboardRepo.getUserLeaderboards(any()),
      ).thenAnswer((_) async => [lb]);
      when(
        () => mockLeaderboardRepo.getMembers(any()),
      ).thenAnswer((_) async => [otherMember]);
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => TestData.profile());

      await vm.load();

      expect(vm.myRank, 0);
    });

    test('returns correct rank when user is in rankings', () async {
      final lb = TestData.leaderboard();
      // u1 is second with lower score (members sorted by repo; just ensure rank calculation)
      final memberA = TestData.leaderboardMember(
        userId: 'user-a',
        weeklyScore: 300,
      );
      final memberB = TestData.leaderboardMember(
        userId: 'u1',
        weeklyScore: 100,
      );
      when(
        () => mockLeaderboardRepo.getUserLeaderboards(any()),
      ).thenAnswer((_) async => [lb]);
      when(
        () => mockLeaderboardRepo.getMembers(any()),
      ).thenAnswer((_) async => [memberA, memberB]);
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => TestData.profile());

      await vm.load();

      expect(vm.myRank, 2);
    });
  });

  // ── createLeaderboard ──────────────────────────────────────────────────────

  group('createLeaderboard', () {
    test(
      'success: leaderboard added to list, selectedLeaderboard updated',
      () async {
        final newLb = TestData.leaderboard(id: 'lb-new', name: 'My Squad');
        when(
          () => mockLeaderboardRepo.createLeaderboard(any(), any(), any()),
        ).thenAnswer((_) async => newLb);
        when(
          () => mockLeaderboardRepo.recalculateMyWeeklyScore(),
        ).thenAnswer((_) async {});
        when(() => mockLeaderboardRepo.getMembers(newLb.id)).thenAnswer(
          (_) async => [
            TestData.leaderboardMember(
              leaderboardId: newLb.id,
              userId: 'u1',
              weeklyScore: 42,
            ),
          ],
        );
        when(
          () => mockProfileRepo.getProfile('u1'),
        ).thenAnswer((_) async => TestData.profile());

        await vm.createLeaderboard('My Squad');

        expect(vm.leaderboards.length, 1);
        expect(vm.leaderboards.first.id, 'lb-new');
        expect(vm.selectedLeaderboard?.id, 'lb-new');
        expect(vm.rankings.single.weeklyScore, 42);
        verifyInOrder([
          () => mockLeaderboardRepo.createLeaderboard('u1', 'My Squad', any()),
          () => mockLeaderboardRepo.recalculateMyWeeklyScore(),
          () => mockLeaderboardRepo.getMembers('lb-new'),
        ]);
        verifyNever(() => mockLeaderboardRepo.recalculateMyWeeklyScore());
      },
    );

    test('failure: error set', () async {
      when(
        () => mockLeaderboardRepo.createLeaderboard(any(), any(), any()),
      ).thenThrow(Exception('create failed'));

      await vm.createLeaderboard('My Squad');

      expect(vm.error, isNotNull);
      verifyNever(() => mockLeaderboardRepo.recalculateMyWeeklyScore());
    });
  });

  // ── joinByInviteCode ───────────────────────────────────────────────────────

  group('joinByInviteCode', () {
    test('success: leaderboard added', () async {
      final lb = TestData.leaderboard(id: 'lb-join');
      when(
        () => mockLeaderboardRepo.getLeaderboardByInviteCode(any()),
      ).thenAnswer((_) async => lb);
      when(
        () => mockLeaderboardRepo.joinLeaderboard(any(), any()),
      ).thenAnswer((_) async => TestData.leaderboardMember());
      when(
        () => mockLeaderboardRepo.recalculateMyWeeklyScore(),
      ).thenAnswer((_) async {});
      when(() => mockLeaderboardRepo.getMembers(any())).thenAnswer(
        (_) async => [
          TestData.leaderboardMember(
            leaderboardId: lb.id,
            userId: 'u1',
            weeklyScore: 42,
          ),
        ],
      );
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => TestData.profile());
      when(() => mockAchievementRepo.evaluateUserAchievements()).thenAnswer(
        (_) async => const [
          UnlockedAchievementEntity(
            id: 'achievement-social',
            code: 'join_private_board',
            name: 'Friendly Start',
            rewardType: RewardType.recognition,
            rewardAmount: 0,
          ),
        ],
      );
      when(
        () => mockAchievementRepo.getUserAchievements('u1'),
      ).thenAnswer((_) async => []);

      await vm.joinByInviteCode('ABC123');

      expect(vm.leaderboards, contains(lb));
      expect(vm.rankings.single.weeklyScore, 42);
      expect(vm.newlyUnlockedAchievements.single.code, 'join_private_board');
      verifyInOrder([
        () => mockLeaderboardRepo.joinLeaderboard('lb-join', 'u1'),
        () => mockLeaderboardRepo.recalculateMyWeeklyScore(),
        () => mockAchievementRepo.evaluateUserAchievements(),
        () => mockLeaderboardRepo.getMembers('lb-join'),
      ]);
      verifyNever(() => mockLeaderboardRepo.recalculateMyWeeklyScore());
    });

    test('invite code not found: error set', () async {
      when(
        () => mockLeaderboardRepo.getLeaderboardByInviteCode(any()),
      ).thenAnswer((_) async => null);

      await vm.joinByInviteCode('INVALID');

      expect(vm.error, contains('not found'));
      verifyNever(() => mockLeaderboardRepo.recalculateMyWeeklyScore());
    });
  });

  // ── clearError ─────────────────────────────────────────────────────────────

  group('clearError', () {
    test('clears the error', () async {
      when(
        () => mockLeaderboardRepo.getLeaderboardByInviteCode(any()),
      ).thenAnswer((_) async => null);
      await vm.joinByInviteCode('INVALID');
      expect(vm.error, isNotNull);

      vm.clearError();

      expect(vm.error, isNull);
    });
  });
}
