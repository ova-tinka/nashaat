import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/core/entities/enums.dart';
import 'package:nashaat/core/entities/achievement-entity.dart';
import 'package:nashaat/core/entities/workout-completion-result.dart';
import 'package:nashaat/core/entities/workout-log-entity.dart';
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
  WorkoutPlanEntity? plan,
}) {
  return ActiveSessionViewModel(
    plan: plan ?? _testPlan(),
    mode: SessionMode.manual,
    logRepo: logRepo ?? MockWorkoutLogRepository(),
    profileRepo: profileRepo ?? MockProfileRepository(),
    achievementRepo: achievementRepo ?? MockAchievementRepository(),
    getUserId: () => 'u1',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(<CompletedExercise>[]);
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

    setUp(() {
      mockLogRepo = MockWorkoutLogRepository();
      mockProfileRepo = MockProfileRepository();
      mockAchievementRepo = MockAchievementRepository();
    });

    WorkoutCompletionResult result({
      int earned = 336,
      int pointsEarned = 150,
      int pointsTotal = 350,
      int currentStreak = 4,
      int longestStreak = 7,
      List<UnlockedAchievementEntity> achievements = const [],
    }) {
      return WorkoutCompletionResult(
        workoutLogId: 'saved-log',
        earnedScreenTimeMinutes: earned,
        pointsEarned: pointsEarned,
        pointsTotal: pointsTotal,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        weeklyScore: 42,
        newlyUnlockedAchievements: achievements,
      );
    }

    void stubSessionStart() {
      when(() => mockLogRepo.startSession('plan1')).thenAnswer(
        (_) async => WorkoutSessionEntity(
          id: 'session1',
          startedAt: DateTime(2026, 4, 18),
        ),
      );
    }

    test('success uses the atomic server completion result', () async {
      stubSessionStart();
      final unlocked = const [
        UnlockedAchievementEntity(
          id: 'achievement-1',
          code: 'first_workout',
          name: 'First Step',
          rewardType: RewardType.points,
          rewardAmount: 50,
        ),
      ];
      when(
        () => mockLogRepo.completeSession(
          sessionId: 'session1',
          completedExercises: any(named: 'completedExercises'),
        ),
      ).thenAnswer((_) async => result(achievements: unlocked));
      when(() => mockProfileRepo.getProfile('u1')).thenAnswer(
        (_) async => TestData.configuredProfile(
          pointsTotal: 350,
          streakCount: 4,
          longestStreak: 7,
        ),
      );
      when(
        () => mockAchievementRepo.getUserAchievements('u1'),
      ).thenAnswer((_) async => []);

      final vm = _makeVm(
        logRepo: mockLogRepo,
        profileRepo: mockProfileRepo,
        achievementRepo: mockAchievementRepo,
      );
      await vm.initialize();
      vm.markAllComplete();
      await vm.saveSession();

      verify(
        () => mockLogRepo.completeSession(
          sessionId: 'session1',
          completedExercises: any(named: 'completedExercises'),
        ),
      ).called(1);
      expect(vm.earnedMinutes, 336);
      expect(vm.pointsEarned, 150);
      expect(vm.pointsTotal, 350);
      expect(vm.currentStreak, 4);
      expect(vm.longestStreak, 7);
      expect(vm.newlyUnlockedAchievements.single.code, 'first_workout');
      expect(vm.error, isNull);
      vm.dispose();
    });

    test(
      'server result controls rewards even when local profile is unconfigured',
      () async {
        stubSessionStart();
        when(
          () => mockLogRepo.completeSession(
            sessionId: 'session1',
            completedExercises: any(named: 'completedExercises'),
          ),
        ).thenAnswer((_) async => result(earned: 0, pointsEarned: 100));
        when(
          () => mockProfileRepo.getProfile('u1'),
        ).thenAnswer((_) async => TestData.profile(pointsTotal: 200));
        when(
          () => mockAchievementRepo.getUserAchievements('u1'),
        ).thenAnswer((_) async => []);

        final vm = _makeVm(
          logRepo: mockLogRepo,
          profileRepo: mockProfileRepo,
          achievementRepo: mockAchievementRepo,
        );
        await vm.initialize();
        vm.markAllComplete();
        await vm.saveSession();

        expect(vm.earnedMinutes, 0);
        expect(vm.pointsEarned, 100);
        expect(vm.error, isNull);
        vm.dispose();
      },
    );

    test(
      'failed completion remains retryable and never reports success',
      () async {
        stubSessionStart();
        var attempts = 0;
        when(
          () => mockLogRepo.completeSession(
            sessionId: 'session1',
            completedExercises: any(named: 'completedExercises'),
          ),
        ).thenAnswer((_) async {
          attempts++;
          if (attempts == 1) throw Exception('network error');
          return result();
        });
        when(
          () => mockProfileRepo.getProfile('u1'),
        ).thenAnswer((_) async => TestData.profile());
        when(
          () => mockAchievementRepo.getUserAchievements('u1'),
        ).thenAnswer((_) async => []);

        final vm = _makeVm(
          logRepo: mockLogRepo,
          profileRepo: mockProfileRepo,
          achievementRepo: mockAchievementRepo,
        );
        await vm.initialize();
        vm.markAllComplete();
        await vm.saveSession();
        expect(vm.error, isNotNull);
        expect(vm.isSaving, isFalse);

        await vm.saveSession();
        expect(vm.error, isNull);
        expect(vm.earnedMinutes, 336);
        verify(
          () => mockLogRepo.completeSession(
            sessionId: 'session1',
            completedExercises: any(named: 'completedExercises'),
          ),
        ).called(2);
        vm.dispose();
      },
    );
  });
}
