import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/core/entities/enums.dart';
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
  MockScreenTimeTransactionRepository? txnRepo,
  WorkoutPlanEntity? plan,
}) {
  return ActiveSessionViewModel(
    plan: plan ?? _testPlan(),
    mode: SessionMode.manual,
    logRepo: logRepo ?? MockWorkoutLogRepository(),
    profileRepo: profileRepo ?? MockProfileRepository(),
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

    test('last set of exercise → exerciseIndex advances, setIndex resets to 0',
        () {
      vm.completeCurrentSet(); // set 0
      vm.completeCurrentSet(); // set 1 → triggers exercise advance

      expect(vm.exerciseIndex, 1);
      expect(vm.setIndex, 0);
    });

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
    late MockScreenTimeTransactionRepository mockTxnRepo;

    setUp(() {
      mockLogRepo = MockWorkoutLogRepository();
      mockProfileRepo = MockProfileRepository();
      mockTxnRepo = MockScreenTimeTransactionRepository();
    });

    test('success with configured profile: createLog called, recordTransaction called',
        () async {
      final savedLog = TestData.workoutLog(id: 'saved-log', earnedScreenTimeMinutes: 336);
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.configuredProfile());
      when(() => mockLogRepo.createLog(any()))
          .thenAnswer((_) async => savedLog);
      when(() => mockTxnRepo.recordTransaction(any()))
          .thenAnswer((_) async => TestData.transaction());
      when(() => mockProfileRepo.updateScreenTimeBalance(any(), any()))
          .thenAnswer((_) async {});

      final vm = _makeVm(
        logRepo: mockLogRepo,
        profileRepo: mockProfileRepo,
        txnRepo: mockTxnRepo,
      );
      vm.markAllComplete();
      await vm.saveSession();

      verify(() => mockLogRepo.createLog(any())).called(1);
      verify(() => mockTxnRepo.recordTransaction(any())).called(1);
      expect(vm.error, isNull);
      vm.dispose();
    });

    test(
        'success with unconfigured profile (dailyPhoneHours=0): earned=0, no transaction',
        () async {
      final savedLog = TestData.workoutLog(id: 'saved-log', earnedScreenTimeMinutes: 0);
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());
      when(() => mockLogRepo.createLog(any()))
          .thenAnswer((_) async => savedLog);

      final vm = _makeVm(
        logRepo: mockLogRepo,
        profileRepo: mockProfileRepo,
        txnRepo: mockTxnRepo,
      );
      vm.markAllComplete();
      await vm.saveSession();

      verifyNever(() => mockTxnRepo.recordTransaction(any()));
      expect(vm.error, isNull);
      vm.dispose();
    });

    test('failure: error set, isSaving=false', () async {
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());
      when(() => mockLogRepo.createLog(any()))
          .thenThrow(Exception('network error'));

      final vm = _makeVm(
        logRepo: mockLogRepo,
        profileRepo: mockProfileRepo,
        txnRepo: mockTxnRepo,
      );
      vm.markAllComplete();
      await vm.saveSession();

      expect(vm.error, isNotNull);
      expect(vm.isSaving, isFalse);
      vm.dispose();
    });
  });
}
