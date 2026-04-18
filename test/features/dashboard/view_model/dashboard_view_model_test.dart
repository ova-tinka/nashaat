import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/core/entities/enums.dart';
import 'package:nashaat/features/dashboard/view-model/dashboard-view-model.dart';

import '../../../helpers/mock_repositories.dart';
import '../../../helpers/test_data.dart';

void main() {
  late MockProfileRepository mockProfileRepo;
  late MockWorkoutLogRepository mockLogRepo;
  late MockScreenTimeTransactionRepository mockTxnRepo;
  late DashboardViewModel vm;

  setUp(() {
    mockProfileRepo = MockProfileRepository();
    mockLogRepo = MockWorkoutLogRepository();
    mockTxnRepo = MockScreenTimeTransactionRepository();
    vm = DashboardViewModel(
      userId: 'u1',
      profileRepo: mockProfileRepo,
      logRepo: mockLogRepo,
      txnRepo: mockTxnRepo,
    );
  });

  tearDown(() => vm.dispose());

  // ── Initial state ──────────────────────────────────────────────────────────

  group('initial state', () {
    test('profile is null', () {
      expect(vm.profile, isNull);
    });

    test('weeklyLogs is empty', () {
      expect(vm.weeklyLogs, isEmpty);
    });

    test('isLoading is false', () {
      expect(vm.isLoading, isFalse);
    });
  });

  // ── load ───────────────────────────────────────────────────────────────────

  group('load', () {
    test('success: profile, weeklyLogs, recentTransactions set', () async {
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());
      when(() => mockLogRepo.getUserLogs(any(), from: any(named: 'from')))
          .thenAnswer((_) async => [TestData.workoutLog()]);
      when(() => mockTxnRepo.getUserTransactions(any(),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => [TestData.transaction()]);

      await vm.load();

      expect(vm.profile, isNotNull);
      expect(vm.weeklyLogs.length, 1);
      expect(vm.error, isNull);
    });

    test('failure: error set', () async {
      when(() => mockProfileRepo.getProfile(any()))
          .thenThrow(Exception('network error'));
      when(() => mockLogRepo.getUserLogs(any(), from: any(named: 'from')))
          .thenAnswer((_) async => []);
      when(() => mockTxnRepo.getUserTransactions(any(),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => []);

      await vm.load();

      expect(vm.error, isNotNull);
    });
  });

  // ── displayName ───────────────────────────────────────────────────────────

  group('displayName', () {
    test('uses username when present', () async {
      when(() => mockProfileRepo.getProfile(any())).thenAnswer(
          (_) async => TestData.profile(username: 'jdoe', firstName: 'John'));
      when(() => mockLogRepo.getUserLogs(any(), from: any(named: 'from')))
          .thenAnswer((_) async => []);
      when(() => mockTxnRepo.getUserTransactions(any(),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => []);

      await vm.load();

      expect(vm.displayName, 'jdoe');
    });

    test('falls back to firstName when no username', () async {
      when(() => mockProfileRepo.getProfile(any())).thenAnswer(
          (_) async => TestData.profile(firstName: 'John'));
      when(() => mockLogRepo.getUserLogs(any(), from: any(named: 'from')))
          .thenAnswer((_) async => []);
      when(() => mockTxnRepo.getUserTransactions(any(),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => []);

      await vm.load();

      expect(vm.displayName, 'John');
    });

    test('falls back to email prefix when no username or firstName', () async {
      when(() => mockProfileRepo.getProfile(any())).thenAnswer(
          (_) async => TestData.profile(email: 'athlete@example.com'));
      when(() => mockLogRepo.getUserLogs(any(), from: any(named: 'from')))
          .thenAnswer((_) async => []);
      when(() => mockTxnRepo.getUserTransactions(any(),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => []);

      await vm.load();

      expect(vm.displayName, 'athlete');
    });
  });

  // ── weeklyEarnedMinutes / weeklySpentMinutes ───────────────────────────────

  group('weeklyEarnedMinutes', () {
    test('sums earned transactions from this week', () async {
      final thisWeek = DateTime.now().subtract(const Duration(days: 1));
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());
      when(() => mockLogRepo.getUserLogs(any(), from: any(named: 'from')))
          .thenAnswer((_) async => []);
      when(() => mockTxnRepo.getUserTransactions(any(),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                TestData.transaction(
                    amountMinutes: 30,
                    transactionType: TransactionType.earned,
                    createdAt: thisWeek),
                TestData.transaction(
                    id: 'txn2',
                    amountMinutes: 20,
                    transactionType: TransactionType.earned,
                    createdAt: thisWeek),
              ]);

      await vm.load();

      expect(vm.weeklyEarnedMinutes, 50);
    });

    test('ignores spent and penalty transactions', () async {
      final thisWeek = DateTime.now().subtract(const Duration(days: 1));
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());
      when(() => mockLogRepo.getUserLogs(any(), from: any(named: 'from')))
          .thenAnswer((_) async => []);
      when(() => mockTxnRepo.getUserTransactions(any(),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                TestData.transaction(
                    amountMinutes: 60,
                    transactionType: TransactionType.spent,
                    createdAt: thisWeek),
                TestData.transaction(
                    id: 'txn2',
                    amountMinutes: 30,
                    transactionType: TransactionType.penalty,
                    createdAt: thisWeek),
              ]);

      await vm.load();

      expect(vm.weeklyEarnedMinutes, 0);
    });
  });

  group('weeklySpentMinutes', () {
    test('sums spent and penalty transactions', () async {
      final thisWeek = DateTime.now().subtract(const Duration(days: 1));
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());
      when(() => mockLogRepo.getUserLogs(any(), from: any(named: 'from')))
          .thenAnswer((_) async => []);
      when(() => mockTxnRepo.getUserTransactions(any(),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                TestData.transaction(
                    amountMinutes: 60,
                    transactionType: TransactionType.spent,
                    createdAt: thisWeek),
                TestData.transaction(
                    id: 'txn2',
                    amountMinutes: 30,
                    transactionType: TransactionType.penalty,
                    createdAt: thisWeek),
              ]);

      await vm.load();

      expect(vm.weeklySpentMinutes, 90);
    });
  });

  // ── weeklyProgress / goalStatus ───────────────────────────────────────────

  group('weeklyProgress', () {
    test('equals minutesTrained / target clamped 0..1', () async {
      when(() => mockProfileRepo.getProfile(any())).thenAnswer((_) async =>
          TestData.profile(weeklyExerciseTargetMinutes: 100));
      when(() => mockLogRepo.getUserLogs(any(), from: any(named: 'from')))
          .thenAnswer((_) async =>
              [TestData.workoutLog(durationMinutes: 50)]);
      when(() => mockTxnRepo.getUserTransactions(any(),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => []);

      await vm.load();

      expect(vm.weeklyProgress, closeTo(0.5, 0.001));
    });

    test('clamped at 1.0 when over target', () async {
      when(() => mockProfileRepo.getProfile(any())).thenAnswer((_) async =>
          TestData.profile(weeklyExerciseTargetMinutes: 30));
      when(() => mockLogRepo.getUserLogs(any(), from: any(named: 'from')))
          .thenAnswer((_) async =>
              [TestData.workoutLog(durationMinutes: 200)]);
      when(() => mockTxnRepo.getUserTransactions(any(),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => []);

      await vm.load();

      expect(vm.weeklyProgress, 1.0);
    });
  });

  group('goalStatus', () {
    Future<void> loadWith({required int target, required int trained}) async {
      when(() => mockProfileRepo.getProfile(any())).thenAnswer(
          (_) async =>
              TestData.profile(weeklyExerciseTargetMinutes: target));
      when(() => mockLogRepo.getUserLogs(any(), from: any(named: 'from')))
          .thenAnswer((_) async =>
              [TestData.workoutLog(durationMinutes: trained)]);
      when(() => mockTxnRepo.getUserTransactions(any(),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => []);
      await vm.load();
    }

    test("returns 'Strong' when progress >= 0.9", () async {
      await loadWith(target: 100, trained: 90);

      expect(vm.goalStatus, 'Strong');
    });

    test("returns 'Stable' when progress >= 0.5 and < 0.9", () async {
      await loadWith(target: 100, trained: 60);

      expect(vm.goalStatus, 'Stable');
    });

    test("returns 'Needs Attention' when progress < 0.5", () async {
      await loadWith(target: 100, trained: 30);

      expect(vm.goalStatus, 'Needs Attention');
    });
  });

  // ── weeklyActivitySpots ───────────────────────────────────────────────────

  group('weeklyActivitySpots', () {
    test('returns exactly 7 values', () async {
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());
      when(() => mockLogRepo.getUserLogs(any(), from: any(named: 'from')))
          .thenAnswer((_) async => []);
      when(() => mockTxnRepo.getUserTransactions(any(),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => []);

      await vm.load();

      expect(vm.weeklyActivitySpots.length, 7);
    });
  });
}
