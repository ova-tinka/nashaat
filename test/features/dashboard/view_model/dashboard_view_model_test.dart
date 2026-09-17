import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/core/entities/enums.dart';
import 'package:nashaat/features/dashboard/view-model/dashboard-view-model.dart';
import 'package:timezone/data/latest_10y.dart' as timezone_data;

import '../../../helpers/mock_repositories.dart';
import '../../../helpers/test_data.dart';

void main() {
  final now = DateTime.utc(2026, 4, 18, 12);
  late MockProfileRepository mockProfileRepo;
  late MockPointAwardRepository mockPointAwardRepo;
  late MockWorkoutLogRepository mockLogRepo;
  late MockScreenTimeTransactionRepository mockTxnRepo;
  late DashboardViewModel vm;

  setUp(() {
    mockProfileRepo = MockProfileRepository();
    mockPointAwardRepo = MockPointAwardRepository();
    mockLogRepo = MockWorkoutLogRepository();
    mockTxnRepo = MockScreenTimeTransactionRepository();
    when(
      () => mockPointAwardRepo.getUserPointAwards(
        any(),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
    vm = DashboardViewModel(
      userId: 'u1',
      profileRepo: mockProfileRepo,
      pointAwardRepo: mockPointAwardRepo,
      logRepo: mockLogRepo,
      txnRepo: mockTxnRepo,
      now: () => now,
    );
  });

  setUpAll(timezone_data.initializeTimeZones);

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
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => TestData.profile());
      when(
        () => mockLogRepo.getUserLogs(any(), from: any(named: 'from')),
      ).thenAnswer((_) async => [TestData.workoutLog()]);
      when(
        () =>
            mockTxnRepo.getUserTransactions(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) async => [TestData.transaction()]);

      await vm.load();

      expect(vm.profile, isNotNull);
      expect(vm.weeklyLogs.length, 1);
      expect(vm.error, isNull);
    });

    test('loads at most three recent point awards', () async {
      final awards = [
        TestData.pointAward(id: 'award1'),
        TestData.pointAward(id: 'award2'),
        TestData.pointAward(id: 'award3'),
      ];
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => TestData.profile());
      when(
        () => mockPointAwardRepo.getUserPointAwards('u1', limit: 3),
      ).thenAnswer((_) async => awards);
      when(
        () => mockLogRepo.getUserLogs(any(), from: any(named: 'from')),
      ).thenAnswer((_) async => []);
      when(
        () =>
            mockTxnRepo.getUserTransactions(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) async => []);

      await vm.load();

      expect(vm.recentPointAwards, awards);
      verify(
        () => mockPointAwardRepo.getUserPointAwards('u1', limit: 3),
      ).called(1);
    });

    test('exposes points_total from the loaded profile', () async {
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => TestData.profile(pointsTotal: 400));
      when(
        () => mockLogRepo.getUserLogs(any(), from: any(named: 'from')),
      ).thenAnswer((_) async => []);
      when(
        () =>
            mockTxnRepo.getUserTransactions(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) async => []);

      await vm.load();

      expect(vm.totalPoints, 400);
    });

    test(
      'exposes current and longest streak from the loaded profile',
      () async {
        when(() => mockProfileRepo.getProfile(any())).thenAnswer(
          (_) async => TestData.profile(
            streakCount: 4,
            longestStreak: 9,
            lastWorkoutDate: DateTime.utc(2026, 4, 17),
          ),
        );
        when(
          () => mockLogRepo.getUserLogs(any(), from: any(named: 'from')),
        ).thenAnswer((_) async => []);
        when(
          () => mockTxnRepo.getUserTransactions(
            any(),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => []);

        await vm.load();

        expect(vm.streakCount, 4);
        expect(vm.longestStreak, 9);
      },
    );

    test('shows zero when the last workout was before yesterday', () async {
      when(() => mockProfileRepo.getProfile(any())).thenAnswer(
        (_) async => TestData.profile(
          streakCount: 8,
          longestStreak: 12,
          lastWorkoutDate: DateTime.utc(2026, 4, 16),
        ),
      );
      when(
        () => mockLogRepo.getUserLogs(any(), from: any(named: 'from')),
      ).thenAnswer((_) async => []);
      when(
        () =>
            mockTxnRepo.getUserTransactions(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) async => []);

      await vm.load();

      expect(vm.streakCount, 0);
      expect(vm.longestStreak, 12);
    });

    test('uses the profile timezone to determine today', () async {
      final nearMidnightUtc = DateTime.utc(2026, 4, 18, 22, 30);
      final timezoneVm = DashboardViewModel(
        userId: 'u1',
        profileRepo: mockProfileRepo,
        pointAwardRepo: mockPointAwardRepo,
        logRepo: mockLogRepo,
        txnRepo: mockTxnRepo,
        now: () => nearMidnightUtc,
      );
      when(() => mockProfileRepo.getProfile(any())).thenAnswer(
        (_) async => TestData.profile(
          streakCount: 5,
          longestStreak: 9,
          lastWorkoutDate: DateTime.utc(2026, 4, 17),
          timezone: 'Asia/Qatar',
        ),
      );
      when(
        () => mockLogRepo.getUserLogs(any(), from: any(named: 'from')),
      ).thenAnswer((_) async => []);
      when(
        () =>
            mockTxnRepo.getUserTransactions(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) async => []);

      await timezoneVm.load();

      expect(timezoneVm.streakCount, 0);
      expect(timezoneVm.longestStreak, 9);
      timezoneVm.dispose();
    });

    test('failure: error set', () async {
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenThrow(Exception('network error'));
      when(
        () => mockLogRepo.getUserLogs(any(), from: any(named: 'from')),
      ).thenAnswer((_) async => []);
      when(
        () =>
            mockTxnRepo.getUserTransactions(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) async => []);

      await vm.load();

      expect(vm.error, isNotNull);
    });
  });

  // ── displayName ───────────────────────────────────────────────────────────

  group('displayName', () {
    test('uses username when present', () async {
      when(() => mockProfileRepo.getProfile(any())).thenAnswer(
        (_) async => TestData.profile(username: 'jdoe', firstName: 'John'),
      );
      when(
        () => mockLogRepo.getUserLogs(any(), from: any(named: 'from')),
      ).thenAnswer((_) async => []);
      when(
        () =>
            mockTxnRepo.getUserTransactions(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) async => []);

      await vm.load();

      expect(vm.displayName, 'jdoe');
    });

    test('falls back to firstName when no username', () async {
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => TestData.profile(firstName: 'John'));
      when(
        () => mockLogRepo.getUserLogs(any(), from: any(named: 'from')),
      ).thenAnswer((_) async => []);
      when(
        () =>
            mockTxnRepo.getUserTransactions(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) async => []);

      await vm.load();

      expect(vm.displayName, 'John');
    });

    test('falls back to email prefix when no username or firstName', () async {
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => TestData.profile(email: 'athlete@example.com'));
      when(
        () => mockLogRepo.getUserLogs(any(), from: any(named: 'from')),
      ).thenAnswer((_) async => []);
      when(
        () =>
            mockTxnRepo.getUserTransactions(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) async => []);

      await vm.load();

      expect(vm.displayName, 'athlete');
    });
  });

  // ── weeklyEarnedMinutes / weeklySpentMinutes ───────────────────────────────

  group('weeklyEarnedMinutes', () {
    test('sums earned transactions from this week', () async {
      final thisWeek = DateTime.now().subtract(const Duration(days: 1));
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => TestData.profile());
      when(
        () => mockLogRepo.getUserLogs(any(), from: any(named: 'from')),
      ).thenAnswer((_) async => []);
      when(
        () =>
            mockTxnRepo.getUserTransactions(any(), limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => [
          TestData.transaction(
            amountMinutes: 30,
            transactionType: TransactionType.earned,
            createdAt: thisWeek,
          ),
          TestData.transaction(
            id: 'txn2',
            amountMinutes: 20,
            transactionType: TransactionType.earned,
            createdAt: thisWeek,
          ),
        ],
      );

      await vm.load();

      expect(vm.weeklyEarnedMinutes, 50);
    });

    test('ignores spent and penalty transactions', () async {
      final thisWeek = DateTime.now().subtract(const Duration(days: 1));
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => TestData.profile());
      when(
        () => mockLogRepo.getUserLogs(any(), from: any(named: 'from')),
      ).thenAnswer((_) async => []);
      when(
        () =>
            mockTxnRepo.getUserTransactions(any(), limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => [
          TestData.transaction(
            amountMinutes: 60,
            transactionType: TransactionType.spent,
            createdAt: thisWeek,
          ),
          TestData.transaction(
            id: 'txn2',
            amountMinutes: 30,
            transactionType: TransactionType.penalty,
            createdAt: thisWeek,
          ),
        ],
      );

      await vm.load();

      expect(vm.weeklyEarnedMinutes, 0);
    });
  });

  group('weeklySpentMinutes', () {
    test('sums spent and penalty transactions', () async {
      final thisWeek = DateTime.now().subtract(const Duration(days: 1));
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => TestData.profile());
      when(
        () => mockLogRepo.getUserLogs(any(), from: any(named: 'from')),
      ).thenAnswer((_) async => []);
      when(
        () =>
            mockTxnRepo.getUserTransactions(any(), limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => [
          TestData.transaction(
            amountMinutes: 60,
            transactionType: TransactionType.spent,
            createdAt: thisWeek,
          ),
          TestData.transaction(
            id: 'txn2',
            amountMinutes: 30,
            transactionType: TransactionType.penalty,
            createdAt: thisWeek,
          ),
        ],
      );

      await vm.load();

      expect(vm.weeklySpentMinutes, 90);
    });
  });

  // ── weeklyProgress / goalStatus ───────────────────────────────────────────

  group('weeklyProgress', () {
    test('equals minutesTrained / target clamped 0..1', () async {
      when(() => mockProfileRepo.getProfile(any())).thenAnswer(
        (_) async => TestData.profile(weeklyExerciseTargetMinutes: 100),
      );
      when(
        () => mockLogRepo.getUserLogs(any(), from: any(named: 'from')),
      ).thenAnswer((_) async => [TestData.workoutLog(durationMinutes: 50)]);
      when(
        () =>
            mockTxnRepo.getUserTransactions(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) async => []);

      await vm.load();

      expect(vm.weeklyProgress, closeTo(0.5, 0.001));
    });

    test('clamped at 1.0 when over target', () async {
      when(() => mockProfileRepo.getProfile(any())).thenAnswer(
        (_) async => TestData.profile(weeklyExerciseTargetMinutes: 30),
      );
      when(
        () => mockLogRepo.getUserLogs(any(), from: any(named: 'from')),
      ).thenAnswer((_) async => [TestData.workoutLog(durationMinutes: 200)]);
      when(
        () =>
            mockTxnRepo.getUserTransactions(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) async => []);

      await vm.load();

      expect(vm.weeklyProgress, 1.0);
    });
  });

  group('goalStatus', () {
    Future<void> loadWith({required int target, required int trained}) async {
      when(() => mockProfileRepo.getProfile(any())).thenAnswer(
        (_) async => TestData.profile(weeklyExerciseTargetMinutes: target),
      );
      when(
        () => mockLogRepo.getUserLogs(any(), from: any(named: 'from')),
      ).thenAnswer(
        (_) async => [TestData.workoutLog(durationMinutes: trained)],
      );
      when(
        () =>
            mockTxnRepo.getUserTransactions(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) async => []);
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
      when(
        () => mockProfileRepo.getProfile(any()),
      ).thenAnswer((_) async => TestData.profile());
      when(
        () => mockLogRepo.getUserLogs(any(), from: any(named: 'from')),
      ).thenAnswer((_) async => []);
      when(
        () =>
            mockTxnRepo.getUserTransactions(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) async => []);

      await vm.load();

      expect(vm.weeklyActivitySpots.length, 7);
    });
  });
}
