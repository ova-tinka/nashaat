import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/core/entities/workout-completion-result.dart';
import 'package:nashaat/core/entities/workout-log-entity.dart';
import 'package:nashaat/features/workout/model/workout-models.dart';
import 'package:nashaat/features/workout/view/active-session-screen.dart';
import 'package:nashaat/features/workout/view-model/active-session-view-model.dart';
import 'package:nashaat/l10n/app_localizations.dart';
import 'package:nashaat/shared/design/molecules/app-timer-ring.dart';
import 'package:nashaat/shared/design/theme.dart';
import 'package:nashaat/shared/design/tokens/app-colors.dart';

import '../../../helpers/mock_repositories.dart';
import '../../../helpers/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(<CompletedExercise>[]);
  });

  testWidgets('guided mode centers the timer and keeps actions available', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 624));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = _viewModel(mode: SessionMode.guided);

    await tester.pumpWidget(
      _app(ActiveSessionScreen(plan: vm.plan, viewModel: vm)),
    );

    expect(find.byType(AppTimerRing), findsOneWidget);
    expect(find.text('Complete set'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('WORKOUT COMPLETE!'), findsNothing);
    expect(tester.takeException(), isNull);
    vm.dispose();
  });

  testWidgets('manual mode uses rounded exercise cards and a finish action', (
    tester,
  ) async {
    final vm = _viewModel(mode: SessionMode.manual);

    await tester.pumpWidget(
      _app(
        ActiveSessionScreen(
          plan: vm.plan,
          mode: SessionMode.manual,
          viewModel: vm,
        ),
      ),
    );

    expect(find.text('Push-up'), findsOneWidget);
    expect(find.text('Finish session', skipOffstage: false), findsOneWidget);
    expect(find.text('S1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    vm.dispose();
  });

  testWidgets('guided mode remains usable in Arabic on a short viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 624));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = _viewModel(mode: SessionMode.guided);
    await tester.pumpWidget(
      _app(
        ActiveSessionScreen(plan: vm.plan, viewModel: vm),
        locale: const Locale('ar'),
      ),
    );

    expect(find.text('إنهاء المجموعة'), findsOneWidget);
    expect(find.byType(AppTimerRing), findsOneWidget);
    expect(tester.takeException(), isNull);
    vm.dispose();
  });

  testWidgets('completion starts the reward reveal after saving', (
    tester,
  ) async {
    final logRepo = MockWorkoutLogRepository();
    final profileRepo = MockProfileRepository();
    final achievementRepo = MockAchievementRepository();

    when(() => logRepo.startSession('plan1')).thenAnswer(
      (_) async => WorkoutSessionEntity(
        id: 'session1',
        startedAt: DateTime(2026, 4, 18),
      ),
    );
    when(
      () => logRepo.completeSession(
        sessionId: 'session1',
        completedExercises: any(named: 'completedExercises'),
      ),
    ).thenAnswer(
      (_) async => const WorkoutCompletionResult(
        workoutLogId: 'log1',
        earnedScreenTimeMinutes: 30,
        pointsEarned: 100,
        pointsTotal: 250,
        currentStreak: 4,
        longestStreak: 6,
        weeklyScore: 100,
      ),
    );
    when(
      () => profileRepo.getProfile('u1'),
    ).thenAnswer((_) async => TestData.profile(pointsTotal: 250));
    when(
      () => achievementRepo.getUserAchievements('u1'),
    ).thenAnswer((_) async => []);

    final vm = ActiveSessionViewModel(
      plan: TestData.workoutPlan(),
      mode: SessionMode.manual,
      logRepo: logRepo,
      profileRepo: profileRepo,
      achievementRepo: achievementRepo,
      getUserId: () => 'u1',
    );
    addTearDown(vm.dispose);
    vm.markAllComplete();

    await tester.pumpWidget(
      _app(ActiveSessionScreen(plan: vm.plan, viewModel: vm)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Strong work'), findsOneWidget);
    expect(find.text('DURATION'), findsOneWidget);
    expect(find.text('REWARD POINTS'), findsNothing);
    expect(find.text('Thanks!'), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('REWARD POINTS'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Thanks!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ActiveSessionViewModel _viewModel({required SessionMode mode}) {
  return ActiveSessionViewModel(
    plan: TestData.workoutPlan(
      exercises: [TestData.planExercise(sets: 2, restSeconds: 0)],
    ),
    mode: mode,
    logRepo: MockWorkoutLogRepository(),
    profileRepo: MockProfileRepository(),
    achievementRepo: MockAchievementRepository(),
    getUserId: () => 'u1',
  );
}

Widget _app(Widget home, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AppTheme.buildTheme(
      locale == const Locale('ar')
          ? NashaatPalette.pearlDay
          : NashaatPalette.majlisNight,
      locale: locale,
    ),
    home: home,
  );
}
