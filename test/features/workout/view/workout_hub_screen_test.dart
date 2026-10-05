import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/core/entities/enums.dart';
import 'package:nashaat/features/workout/view-model/workout-hub-view-model.dart';
import 'package:nashaat/features/workout/view/workout-hub-screen.dart';
import 'package:nashaat/l10n/app_localizations.dart';
import 'package:nashaat/shared/design/molecules/app-segmented-control.dart';
import 'package:nashaat/shared/design/theme.dart';
import 'package:nashaat/shared/design/tokens/app-colors.dart';

import '../../../helpers/mock_repositories.dart';
import '../../../helpers/test_data.dart';

void main() {
  late MockWorkoutPlanRepository planRepository;
  late MockProfileRepository profileRepository;

  setUp(() {
    planRepository = MockWorkoutPlanRepository();
    profileRepository = MockProfileRepository();
  });

  WorkoutHubViewModel buildViewModel() => WorkoutHubViewModel(
    userId: 'u1',
    repo: planRepository,
    profileRepo: profileRepository,
  );

  testWidgets('leads with the next workout and plan hierarchy', (tester) async {
    final today = DateTime.now().weekday;
    when(() => planRepository.getUserPlans(any())).thenAnswer(
      (_) async => [
        TestData.workoutPlan(title: 'Morning Routine', scheduledDays: [today]),
        TestData.workoutPlan(id: 'plan2', title: 'Evening Walk'),
      ],
    );
    when(
      () => profileRepository.getProfile(any()),
    ).thenAnswer((_) async => TestData.profile());

    final vm = buildViewModel();
    addTearDown(vm.dispose);

    await tester.pumpWidget(_app(WorkoutHubScreen(viewModel: vm)));
    await tester.pumpAndSettle();

    expect(find.text('Workouts'), findsOneWidget);
    expect(find.byType(AppSegmentedControl<int>), findsOneWidget);
    expect(find.text('Next workout'), findsOneWidget);
    expect(find.text('Morning Routine'), findsAtLeastNWidgets(1));
    expect(find.text('Your plans'), findsOneWidget);
    expect(find.text('Start Workout'), findsAtLeastNWidgets(1));
    expect(find.text('WORKOUTS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the empty state with a create-plan action', (
    tester,
  ) async {
    when(() => planRepository.getUserPlans(any())).thenAnswer((_) async => []);
    when(
      () => profileRepository.getProfile(any()),
    ).thenAnswer((_) async => TestData.profile());

    final vm = buildViewModel();
    addTearDown(vm.dispose);

    await tester.pumpWidget(_app(WorkoutHubScreen(viewModel: vm)));
    await tester.pumpAndSettle();

    expect(find.text('No plans yet'), findsOneWidget);
    expect(find.text('Create new plan'), findsNothing);
    expect(find.text('New plan'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches to the VIP treatment in the AI segment', (
    tester,
  ) async {
    when(() => planRepository.getUserPlans(any())).thenAnswer((_) async => []);
    when(() => profileRepository.getProfile(any())).thenAnswer(
      (_) async => TestData.profile(subscriptionTier: SubscriptionTier.free),
    );

    final vm = buildViewModel();
    addTearDown(vm.dispose);

    await tester.pumpWidget(_app(WorkoutHubScreen(viewModel: vm)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();

    expect(find.text('AI workouts'), findsOneWidget);
    expect(find.text('Upgrade to VIP'), findsOneWidget);
    expect(find.text('AI-generated workout plans'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget home) {
  return MaterialApp(
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AppTheme.buildTheme(NashaatPalette.majlisNight),
    home: home,
  );
}
