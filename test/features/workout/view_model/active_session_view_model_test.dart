import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/core/entities/enums.dart';
import 'package:nashaat/core/entities/achievement-entity.dart';
import 'package:nashaat/core/entities/point-award-entity.dart';
import 'package:nashaat/core/entities/workout-plan-entity.dart';
import 'package:nashaat/features/workout/model/workout-models.dart';
import 'package:nashaat/features/workout/view-model/active-session-view-model.dart';

import '../../../helpers/mock_repositories.dart';
import '../../../helpers/test_data.dart';

// Helper: plan with 2 exercises each having 2 sets
WorkoutPlanEntity _testPlan() {
  return WorkoutPlanEntity(
    id: 'plan1',
    userId: 'u1',
    title: 'Test Plan',
    source: WorkoutSource.manual,
    scheduledDays: const [],
    exercises: const [
      WorkoutPlanExercise(
        exerciseId: 'ex1',
        exerciseName: 'Push-up',
        sets: 2,
        reps: 10,
        restSeconds: 0, // no rest so tests don't need timers
      ),
      WorkoutPlanExercise(
        exerciseId: 'ex2',
        exerciseName: 'Squat',
        sets: 2,
        reps: 12,
        restSeconds: 0,
      ),
    ],
    sessionSize: SessionSize.small,
    createdAt: DateTime(2026, 4, 18),
    updatedAt: DateTime(2026, 4, 18),
  );
}

ActiveSessionViewModel _makeVm({
  MockWorkoutLogRepository? logRepo,
  MockProfileRepository? profileRepo,
  MockAchievementRepository? achievementRepo,
  MockPointAwardRepository? pointAwardRepo,
  MockLeaderboardRepository? leaderboardRepo,
  MockScreenTimeTransactionRepository? txnRepo,
  WorkoutPlanEntity? plan,
}) {
  return ActiveSessionViewModel(
    plan: plan ?? _testPlan(),
    mode: SessionMode.manual,
    logRepo: logRepo ?? MockWorkoutLogRepository(),
    profileRepo: profileRepo ?? MockProfileRepository(),
    achievementRepo: achievementRepo ?? MockAchievementRepository(),
    pointAwardRepo: pointAwardRepo ?? MockPointAwardRepository(),
    leaderboardRepo: leaderboardRepo ?? MockLeaderboardRepository(),
    txnRepo: txnRepo ?? MockScreenTimeTransactionRepository(),
    getUserId: () => 'u1',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(TestData.workoutLog());
    registerFallbackValue(TestData.transaction());
  });

  // ── Initial state ──────────────────────────────────────────────────────────

  group('initial state', () {
    late ActiveSessionViewModel vm;
    setUp(() => vm = _makeVm());
    tearDown(() => vm.dispose());

    test('exerciseIndex is 0', () {
      expect(vm.exerciseIndex, 0);
    });

    test('setIndex is 0', () {
      expect(vm.setIndex, 0);
    });

    test('overallProgress is 0', () {
      expect(vm.overallProgress, 0.0);
    });

    testWidgets('manual sessions track elapsed time', (tester) async {
      final timedVm = _makeVm();
      expect(timedVm.status, ActiveSessionStatus.running);
      await tester.pump(const Duration(seconds: 1));
      expect(timedVm.elapsedSeconds, 1);
      timedVm.dispose();
    });
  });

  // ── overallProgress ────────────────────────────────────────────────────────

  group('overallProgress', () {
    test('is 1.0 after all sets completed', () {
      final vm = _makeVm();
      vm.markAllComplete();

      expect(vm.overallProgress, 1.0);
      vm.dispose();
    });
  });

  // ── completeCurrentSet ─────────────────────────────────────────────────────

  group('completeCurrentSet', () {
    late ActiveSessionViewModel vm;
    setUp(() => vm = _makeVm());
    tearDown(() => vm.dispose());

    test('advances setIndex within same exercise', () {
      vm.completeCurrentSet();

      expect(vm.exerciseIndex, 0);
      expect(vm.setIndex, 1);
    });

    test(
      'last set of exercise → exerciseIndex advances, setIndex resets to 0',
      () {
        vm.completeCurrentSet(); // set 0
        vm.completeCurrentSet(); // set 1 → triggers exercise advance

        expect(vm.exerciseIndex, 1);
        expect(vm.setIndex, 0);
      },
    );

    test('last set of last exercise → status is completed', () {
      // Complete all 4 sets (2 exercises × 2 sets)
      for (int i = 0; i < 4; i++) {
        vm.completeCurrentSet();
      }

      expect(vm.status, ActiveSessionStatus.completed);
    });
  });

  // ── skipCurrentSet ─────────────────────────────────────────────────────────

  group('skipCurrentSet', () {
    late ActiveSessionViewModel vm;
    setUp(() => vm = _makeVm());
    tearDown(() => vm.dispose());

    test('behaves like completeCurrentSet', () {
      vm.skipCurrentSet();

      expect(vm.exerciseIndex, 0);
      expect(vm.setIndex, 1);
    });
  });

  // ── toggleSet ─────────────────────────────────────────────────────────────

  group('toggleSet', () {
    late ActiveSessionViewModel vm;
    setUp(() => vm = _makeVm());
    tearDown(() => vm.dispose());

    test('toggles a boolean in setCompletions', () {
      expect(vm.setCompletions[0][0], isFalse);

      vm.toggleSet(0, 0);
      expect(vm.setCompletions[0][0], isTrue);

      vm.toggleSet(0, 0);
      expect(vm.setCompletions[0][0], isFalse);
    });
  });

  // ── markExerciseDone ──────────────────────────────────────────────────────

  group('markExerciseDone', () {
    late ActiveSessionViewModel vm;
    setUp(() => vm = _makeVm());
    tearDown(() => vm.dispose());

    test('marks all sets for that exercise as done', () {
      vm.markExerciseDone(0);

      expect(vm.setCompletions[0], everyElement(isTrue));
    });

    test('advances exerciseIndex to next exercise', () {
      vm.markExerciseDone(0);

      expect(vm.exerciseIndex, 1);
    });

    test('last exercise → status is completed', () {
      vm.markExerciseDone(0);
      vm.markExerciseDone(1);

      expect(vm.status, ActiveSessionStatus.completed);
    });
  });

  // ── markAllComplete ────────────────────────────────────────────────────────

  group('markAllComplete', () {
    test('status becomes completed and all sets are true', () {
      final vm = _makeVm();
      vm.markAllComplete();

      expect(vm.status, ActiveSessionStatus.completed);
      for (final sets in vm.setCompletions) {
        expect(sets, everyElement(isTrue));
      }
      vm.dispose();
    });
  });

  // ── saveSession ────────────────────────────────────────────────────────────

  group('saveSession', () {
    late MockWorkoutLogRepository mockLogRepo;
    late MockProfileRepository mockProfileRepo;
    late MockAchievementRepository mockAchievementRepo;
    late MockPointAwardRepository mockPointAwardRepo;
    late MockLeaderboardRepository mockLeaderboardRepo;
    late MockScreenTimeTransactionRepository mockTxnRepo;

    setUp(() {
      mockLogRepo = MockWorkoutLogRepository();
      mockProfileRepo = MockProfileRepository();
      mockAchievementRepo = MockAchievementRepository();
      mockPointAwardRepo = MockPointAwardRepository();
      mockLeaderboardRepo = MockLeaderboardRepository();
      when(
        () => mockLeaderboardRepo.recalculateMyWeeklyScore(),
      ).thenAnswer((_) async {});
      mockTxnRepo = MockScreenTimeTransactionRepository();
    });

    test(
      'success with configured profile: createLog called, recordTransaction called',
      () async {
        final savedLog = TestData.workoutLog(
          id: 'saved-log',
          earnedScreenTimeMinutes: 336,
        );
        when(() => mockProfileRepo.getProfile(any())).thenAnswer(
          (_) async => TestData.configuredProfile(
            pointsTotal: 350,
            streakCount: 4,
            longestStreak: 7,
          ),
        );
        when(
          () => mockLogRepo.createLog(any()),
        ).thenAnswer((_) async => savedLog);
        when(
          () => mockPointAwardRepo.awardWorkoutPoints('saved-log'),
        ).thenAnswer(
          (_) async => const WorkoutPointsResult(
            pointsEarned: 100,
            pointsTotal: 300,
            currentStreak: 4,
            longestStreak: 7,
          ),
        );
        when(
          () => mockPointAwardRepo.awardStreakMilestonePoints('saved-log'),
        ).thenAnswer(
          (_) async => const StreakMilestoneResult(
            streakDays: 4,
            bonusPoints: 0,
            pointsTotal: 300,
          ),
        );
        when(() => mockAchievementRepo.evaluateUserAchievements()).thenAnswer(
          (_) async => const [
            UnlockedAchievementEntity(
              id: 'achievement-1',
              code: 'first_workout',
              name: 'First Step',
              rewardType: RewardType.points,
              rewardAmount: 50,
            ),
          ],
        );
        when(
          () => mockAchievementRepo.getUserAchievements('u1'),
        ).thenAnswer((_) async => []);
        when(
          () => mockTxnRepo.recordTransaction(any()),
        ).thenAnswer((_) async => TestData.transaction());
        when(
          () => mockProfileRepo.updateScreenTimeBalance(any(), any()),
        ).thenAnswer((_) async {});

        final vm = _makeVm(
          logRepo: mockLogRepo,
          profileRepo: mockProfileRepo,
          achievementRepo: mockAchievementRepo,
          pointAwardRepo: mockPointAwardRepo,
          leaderboardRepo: mockLeaderboardRepo,
          txnRepo: mockTxnRepo,
        );
        vm.markAllComplete();
        await vm.saveSession();

        verify(() => mockLogRepo.createLog(any())).called(1);
        verifyInOrder([
          () => mockPointAwardRepo.awardWorkoutPoints('saved-log'),
          () => mockPointAwardRepo.awardStreakMilestonePoints('saved-log'),
          () => mockLeaderboardRepo.recalculateMyWeeklyScore(),
          () => mockAchievementRepo.evaluateUserAchievements(),
        ]);
        verify(() => mockTxnRepo.recordTransaction(any())).called(1);
        expect(vm.pointsEarned, 100);
        expect(vm.pointsTotal, 350);
        expect(vm.currentStreak, 4);
        expect(vm.longestStreak, 7);
        expect(vm.newlyUnlockedAchievements.single.code, 'first_workout');
        expect(vm.error, isNull);
        vm.dispose();
      },
    );

    test(
      'success with unconfigured profile (dailyPhoneHours=0): earned=0, no transaction',
      () async {
        final savedLog = TestData.workoutLog(
          id: 'saved-log',
          earnedScreenTimeMinutes: 0,
        );
        when(() => mockProfileRepo.getProfile(any())).thenAnswer(
          (_) async => TestData.profile(
            pointsTotal: 200,
            streakCount: 2,
            longestStreak: 5,
          ),
        );
        when(
          () => mockLogRepo.createLog(any()),
        ).thenAnswer((_) async => savedLog);
        when(
          () => mockPointAwardRepo.awardWorkoutPoints('saved-log'),
        ).thenAnswer(
          (_) async => const WorkoutPointsResult(
            pointsEarned: 0,
            pointsTotal: 200,
            currentStreak: 2,
            longestStreak: 5,
          ),
        );
        when(
          () => mockPointAwardRepo.awardStreakMilestonePoints('saved-log'),
        ).thenAnswer(
          (_) async => const StreakMilestoneResult(
            streakDays: 2,
            bonusPoints: 0,
            pointsTotal: 200,
          ),
        );
        when(
          () => mockAchievementRepo.evaluateUserAchievements(),
        ).thenAnswer((_) async => []);
        when(
          () => mockAchievementRepo.getUserAchievements('u1'),
        ).thenAnswer((_) async => []);

        final vm = _makeVm(
          logRepo: mockLogRepo,
          profileRepo: mockProfileRepo,
          achievementRepo: mockAchievementRepo,
          pointAwardRepo: mockPointAwardRepo,
          leaderboardRepo: mockLeaderboardRepo,
          txnRepo: mockTxnRepo,
        );
        vm.markAllComplete();
        await vm.saveSession();

        verifyNever(() => mockTxnRepo.recordTransaction(any()));
        verify(() => mockLeaderboardRepo.recalculateMyWeeklyScore()).called(1);
        expect(vm.pointsEarned, 0);
        expect(vm.pointsTotal, 200);
        expect(vm.currentStreak, 2);
        expect(vm.longestStreak, 5);
        expect(vm.error, isNull);
        vm.dispose();
      },
    );

    test('failure: error set, isSaving=false', () async {
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => TestData.profile());
      when(
        () => mockLogRepo.createLog(any()),
      ).thenThrow(Exception('network error'));

      final vm = _makeVm(
        logRepo: mockLogRepo,
        profileRepo: mockProfileRepo,
        achievementRepo: mockAchievementRepo,
        pointAwardRepo: mockPointAwardRepo,
        leaderboardRepo: mockLeaderboardRepo,
        txnRepo: mockTxnRepo,
      );
      vm.markAllComplete();
      await vm.saveSession();

      expect(vm.error, isNotNull);
      expect(vm.isSaving, isFalse);
      verifyNever(() => mockLeaderboardRepo.recalculateMyWeeklyScore());
      vm.dispose();
    });

    test('one-minute workouts recalculate after points update', () async {
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => TestData.profile());
      when(() => mockLogRepo.createLog(any())).thenAnswer(
        (_) async => TestData.workoutLog(id: 'short-log', durationMinutes: 1),
      );
      when(() => mockPointAwardRepo.awardWorkoutPoints('short-log')).thenAnswer(
        (_) async => const WorkoutPointsResult(
          pointsEarned: 0,
          pointsTotal: 0,
          currentStreak: 0,
          longestStreak: 0,
        ),
      );
      when(
        () => mockPointAwardRepo.awardStreakMilestonePoints('short-log'),
      ).thenAnswer(
        (_) async => const StreakMilestoneResult(
          streakDays: 0,
          bonusPoints: 0,
          pointsTotal: 0,
        ),
      );
      when(
        () => mockAchievementRepo.evaluateUserAchievements(),
      ).thenAnswer((_) async => []);
      when(
        () => mockAchievementRepo.getUserAchievements('u1'),
      ).thenAnswer((_) async => []);

      final vm = _makeVm(
        logRepo: mockLogRepo,
        profileRepo: mockProfileRepo,
        achievementRepo: mockAchievementRepo,
        pointAwardRepo: mockPointAwardRepo,
        leaderboardRepo: mockLeaderboardRepo,
        txnRepo: mockTxnRepo,
      );
      vm.markAllComplete();
      await vm.saveSession();

      expect(vm.error, isNull);
      verifyInOrder([
        () => mockPointAwardRepo.awardWorkoutPoints('short-log'),
        () => mockPointAwardRepo.awardStreakMilestonePoints('short-log'),
        () => mockLeaderboardRepo.recalculateMyWeeklyScore(),
      ]);
      vm.dispose();
    });

    test('milestone failure does not fail the saved workout', () async {
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => TestData.profile(pointsTotal: 100));
      when(() => mockLogRepo.createLog(any())).thenAnswer(
        (_) async => TestData.workoutLog(id: 'saved-log'),
      );
      when(() => mockPointAwardRepo.awardWorkoutPoints('saved-log')).thenAnswer(
        (_) async => const WorkoutPointsResult(
          pointsEarned: 100,
          pointsTotal: 100,
          currentStreak: 3,
          longestStreak: 3,
        ),
      );
      when(
        () => mockPointAwardRepo.awardStreakMilestonePoints('saved-log'),
      ).thenThrow(Exception('milestone RPC unavailable'));
      when(
        () => mockAchievementRepo.evaluateUserAchievements(),
      ).thenAnswer((_) async => []);
      when(
        () => mockAchievementRepo.getUserAchievements('u1'),
      ).thenAnswer((_) async => []);

      final vm = _makeVm(
        logRepo: mockLogRepo,
        profileRepo: mockProfileRepo,
        achievementRepo: mockAchievementRepo,
        pointAwardRepo: mockPointAwardRepo,
        leaderboardRepo: mockLeaderboardRepo,
        txnRepo: mockTxnRepo,
      );
      vm.markAllComplete();
      await vm.saveSession();

      expect(vm.error, isNull);
      expect(vm.pointsEarned, 100);
      verifyInOrder([
        () => mockPointAwardRepo.awardWorkoutPoints('saved-log'),
        () => mockPointAwardRepo.awardStreakMilestonePoints('saved-log'),
        () => mockLeaderboardRepo.recalculateMyWeeklyScore(),
        () => mockProfileRepo.getProfile('u1'),
      ]);
      vm.dispose();
    });
  });
}
