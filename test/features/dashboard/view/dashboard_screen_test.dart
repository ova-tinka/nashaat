import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:nashaat/features/achievements/view-model/achievements-view-model.dart';
import 'package:nashaat/features/dashboard/view-model/dashboard-view-model.dart';
import 'package:nashaat/features/dashboard/view/dashboard-screen.dart';
import 'package:nashaat/shared/design/molecules/app-streak-loom.dart';
import 'package:nashaat/shared/design/theme.dart';
import 'package:nashaat/shared/design/tokens/app-colors.dart';

import '../../../helpers/mock_repositories.dart';
import '../../../helpers/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home leads with points, streak loom, and recent points', (
    tester,
  ) async {
    final fixture = _dashboardFixture();
    final dashboardVm = fixture.vm;
    final achievementsVm = _achievementsViewModel();
    await _loadDashboardData(fixture);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(NashaatPalette.majlisNight),
        home: DashboardScreen(
          viewModel: dashboardVm,
          achievementsViewModel: achievementsVm,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('WELCOME BACK,'), findsOneWidget);
    expect(find.text('PROGRESS'), findsNothing);
    expect(find.text('TOTAL POINTS'), findsOneWidget);
    expect(find.text('1,035'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-balance-card')), findsOneWidget);
    expect(find.text('2h 12m'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-start-workout')), findsOneWidget);
    expect(find.text('Weekly goal'), findsOneWidget);
    expect(find.text('YOUR LOOM'), findsOneWidget);
    expect(find.byType(AppStreakLoom), findsOneWidget);
    expect(find.text('Recent points'), findsOneWidget);

    dashboardVm.dispose();
    achievementsVm.dispose();
  });

  testWidgets('Home keeps achievements behind the shared segmented control', (
    tester,
  ) async {
    final fixture = _dashboardFixture();
    final dashboardVm = fixture.vm;
    final achievementsVm = _achievementsViewModel();
    await _loadDashboardData(fixture);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(NashaatPalette.pearlDay),
        home: DashboardScreen(
          viewModel: dashboardVm,
          achievementsViewModel: achievementsVm,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('Achievements'));
    await tester.pump();

    expect(find.byType(AppStreakLoom), findsNothing);
    expect(find.text('No active achievements yet.'), findsOneWidget);

    dashboardVm.dispose();
    achievementsVm.dispose();
  });
}

class _DashboardFixture {
  final MockProfileRepository profileRepo;
  final MockPointAwardRepository pointAwardRepo;
  final MockWorkoutLogRepository logRepo;
  final MockScreenTimeTransactionRepository txnRepo;
  final DashboardViewModel vm;

  _DashboardFixture({
    required this.profileRepo,
    required this.pointAwardRepo,
    required this.logRepo,
    required this.txnRepo,
    required this.vm,
  });
}

_DashboardFixture _dashboardFixture() {
  final profileRepo = MockProfileRepository();
  final pointAwardRepo = MockPointAwardRepository();
  final logRepo = MockWorkoutLogRepository();
  final txnRepo = MockScreenTimeTransactionRepository();
  final vm = DashboardViewModel(
    userId: 'u1',
    profileRepo: profileRepo,
    pointAwardRepo: pointAwardRepo,
    logRepo: logRepo,
    txnRepo: txnRepo,
  );
  return _DashboardFixture(
    profileRepo: profileRepo,
    pointAwardRepo: pointAwardRepo,
    logRepo: logRepo,
    txnRepo: txnRepo,
    vm: vm,
  );
}

AchievementsViewModel _achievementsViewModel() {
  final repository = MockAchievementRepository();
  when(
    () => repository.getDefinitions(activeOnly: true),
  ).thenAnswer((_) async => []);
  when(() => repository.getUserAchievements('u1')).thenAnswer((_) async => []);
  return AchievementsViewModel(userId: 'u1', achievementRepo: repository);
}

Future<void> _loadDashboardData(_DashboardFixture fixture) async {
  when(() => fixture.profileRepo.getProfile('u1')).thenAnswer(
    (_) async => TestData.profile(
      username: 'Khalid',
      screenTimeBalanceMinutes: 132,
      pointsTotal: 1035,
      streakCount: 5,
      longestStreak: 9,
    ),
  );
  when(
    () => fixture.pointAwardRepo.getUserPointAwards('u1', limit: 3),
  ).thenAnswer((_) async => [TestData.pointAward(points: 130)]);
  when(
    () => fixture.logRepo.getUserLogs(any(), from: any(named: 'from')),
  ).thenAnswer((_) async => [TestData.workoutLog(durationMinutes: 95)]);
  when(
    () =>
        fixture.txnRepo.getUserTransactions(any(), limit: any(named: 'limit')),
  ).thenAnswer((_) async => [TestData.transaction(amountMinutes: 132)]);

  await fixture.vm.load();
}
