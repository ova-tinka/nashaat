import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nashaat/app/app-coordinator.dart';
import 'package:nashaat/features/onboarding/coordinator/onboarding-coordinator.dart';
import 'package:nashaat/features/onboarding/view-model/onboarding-view-model.dart';
import 'package:nashaat/features/onboarding/view/onboarding-screen.dart';
import 'package:nashaat/l10n/app_localizations.dart';
import 'package:nashaat/shared/design/molecules/app-dotted-slider.dart';
import 'package:nashaat/shared/design/molecules/app-step-progress.dart';
import 'package:nashaat/shared/design/organisms/app-step-scaffold.dart';
import 'package:nashaat/shared/design/theme.dart';
import 'package:nashaat/shared/design/tokens/app-colors.dart';
import 'package:nashaat/shared/design/tokens/app-spacing.dart';

import '../../../helpers/mock_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppStepScaffold', () {
    testWidgets('keeps progress and CTA visible on a short viewport', (
      tester,
    ) async {
      var wentBack = false;

      await tester.binding.setSurfaceSize(const Size(320, 624));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _testApp(
          home: AppStepScaffold(
            totalSteps: 6,
            currentStep: 2,
            progressLabel: 'Step 3 of 6',
            onBack: () => wentBack = true,
            onNext: () {},
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: const SizedBox(
                height: 900,
                child: Text('Scrollable onboarding content'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AppStepProgress), findsOneWidget);
      expect(find.text('Step 3 of 6'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Back'));
      expect(wentBack, isTrue);
    });

    testWidgets('uses the RTL back direction without overflowing', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 624));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _testApp(
          locale: const Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: AppStepScaffold(
              totalSteps: 3,
              currentStep: 1,
              progressLabel: 'Step 2 of 3',
              onBack: () {},
              onNext: () {},
              body: const SingleChildScrollView(
                padding: EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Text('محتوى الإعداد'),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('OnboardingScreen', () {
    late MockProfileRepository profileRepository;
    late MockBlockingRepository blockingRepository;
    late OnboardingViewModel viewModel;

    setUp(() {
      profileRepository = MockProfileRepository();
      blockingRepository = MockBlockingRepository();
      viewModel = OnboardingViewModel(
        profileRepo: profileRepository,
        blockingRepo: blockingRepository,
        getUserId: () => 'u1',
      );
    });

    tearDown(() => viewModel.dispose());

    testWidgets('uses reference headings and the dotted phone slider', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 624));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_onboardingApp(viewModel));
      expect(find.text('Nashaat'), findsOneWidget);
      expect(find.text('Welcome to Nashaat'), findsNothing);

      await tester.tap(find.text("Let's go"));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(viewModel.step, 3);
      expect(find.byType(AppDottedSlider), findsOneWidget);
      expect(find.text('8h'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Arabic onboarding and navigates back in RTL', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 624));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _onboardingApp(viewModel, locale: const Locale('ar')),
      );
      expect(find.text('Nashaat'), findsOneWidget);
      expect(find.text('لنبدأ'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('لنبدأ'));
      await tester.pump();
      expect(viewModel.step, 1);
      expect(find.text('كم يوماً ستتمرن كل أسبوع؟'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);

      await tester.tap(find.byTooltip('رجوع'));
      await tester.pump();
      expect(viewModel.step, 0);
    });
  });
}

Widget _onboardingApp(
  OnboardingViewModel viewModel, {
  Locale locale = const Locale('en'),
}) {
  return _testApp(
    locale: locale,
    home: OnboardingScreen(
      vm: viewModel,
      coordinator: OnboardingCoordinator(AppCoordinator()),
    ),
  );
}

Widget _testApp({required Widget home, Locale locale = const Locale('en')}) {
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
