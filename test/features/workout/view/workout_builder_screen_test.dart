import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nashaat/features/workout/view-model/workout-builder-view-model.dart';
import 'package:nashaat/features/workout/view/workout-builder-screen.dart';
import 'package:nashaat/l10n/app_localizations.dart';
import 'package:nashaat/shared/design/theme.dart';
import 'package:nashaat/shared/design/tokens/app-colors.dart';

import '../../../helpers/mock_repositories.dart';
import '../../../helpers/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('keeps the sticky save action visible with an exercise card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 624));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = _viewModel(withExercise: true);
    addTearDown(vm.dispose);

    await tester.pumpWidget(_app(WorkoutBuilderScreen(viewModel: vm)));

    expect(find.text('New plan'), findsOneWidget);
    expect(find.text('Exercises'), findsOneWidget);
    expect(find.text('1 exercise'), findsAtLeastNWidgets(1));
    expect(find.text('Push-up'), findsOneWidget);
    expect(find.text('Save plan'), findsOneWidget);
    expect(find.text('Confirm'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('surfaces ViewModel validation in the shared error banner', (
    tester,
  ) async {
    final vm = _viewModel();
    addTearDown(vm.dispose);

    await tester.pumpWidget(_app(WorkoutBuilderScreen(viewModel: vm)));
    await tester.enterText(find.byType(TextFormField).first, 'Push Day');
    await tester.tap(find.text('Save plan'));
    await tester.pump();

    expect(find.text('Please add at least one exercise.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the builder in Arabic without breaking the footer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 624));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = _viewModel(withExercise: true);
    addTearDown(vm.dispose);

    await tester.pumpWidget(
      _app(WorkoutBuilderScreen(viewModel: vm), locale: const Locale('ar')),
    );

    expect(find.text('خطة جديدة'), findsOneWidget);
    expect(find.text('حفظ الخطة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

WorkoutBuilderViewModel _viewModel({bool withExercise = false}) {
  final vm = WorkoutBuilderViewModel(
    planRepo: MockWorkoutPlanRepository(),
    exerciseRepo: MockExerciseRepository(),
    getUserId: () => 'u1',
  );
  vm.setTitleFromController('Push Day');
  vm.toggleDay(DateTime.now().weekday);
  if (withExercise) vm.addExercise(TestData.exercise());
  return vm;
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
