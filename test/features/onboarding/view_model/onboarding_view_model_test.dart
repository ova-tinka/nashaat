import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/core/entities/enums.dart';
import 'package:nashaat/features/onboarding/view-model/onboarding-view-model.dart';

import '../../../helpers/mock_repositories.dart';
import '../../../helpers/test_data.dart';

void main() {
  late MockProfileRepository mockProfileRepo;
  late MockBlockingRepository mockBlockingRepo;
  late OnboardingViewModel vm;

  setUpAll(() {
    registerFallbackValue(TestData.blockingRule());
    registerFallbackValue(TestData.profile());
    // Register UserStatus fallback so any() works with it as positional arg
    registerFallbackValue(UserStatus.active);
  });

  setUp(() {
    mockProfileRepo = MockProfileRepository();
    mockBlockingRepo = MockBlockingRepository();
    vm = OnboardingViewModel(
      profileRepo: mockProfileRepo,
      blockingRepo: mockBlockingRepo,
      getUserId: () => 'u1',
    );
  });

  tearDown(() => vm.dispose());

  // ── Initial state ──────────────────────────────────────────────────────────

  group('initial state', () {
    test('step is 0', () {
      expect(vm.step, 0);
    });

    test('daysPerWeek is 4', () {
      expect(vm.daysPerWeek, 4);
    });

    test('workoutDurationMinutes is 30', () {
      expect(vm.workoutDurationMinutes, 30);
    });

    test('dailyPhoneHours is 8', () {
      expect(vm.dailyPhoneHours, 8);
    });

    test('isDone is false', () {
      expect(vm.isDone, isFalse);
    });
  });

  // ── goNext / goBack ────────────────────────────────────────────────────────

  group('goNext', () {
    test('increments step from 0 to 1', () {
      vm.goNext();

      expect(vm.step, 1);
    });

    test('does not exceed step 5 (total steps - 1)', () {
      for (int i = 0; i < 20; i++) {
        vm.goNext();
      }

      expect(vm.step, 5);
    });
  });

  group('goBack', () {
    test('from step 2 returns true, step becomes 1', () {
      vm.goNext();
      vm.goNext();

      final result = vm.goBack();

      expect(result, isTrue);
      expect(vm.step, 1);
    });

    test('from step 0 returns false, step stays 0', () {
      final result = vm.goBack();

      expect(result, isFalse);
      expect(vm.step, 0);
    });
  });

  // ── setters ────────────────────────────────────────────────────────────────

  group('setters', () {
    test('setUsername updates state', () {
      vm.setUsername('jdoe');

      expect(vm.username, 'jdoe');
    });

    test('setDaysPerWeek updates state', () {
      vm.setDaysPerWeek(5);

      expect(vm.daysPerWeek, 5);
    });

    test('setWorkoutDurationMinutes updates state', () {
      vm.setWorkoutDurationMinutes(45);

      expect(vm.workoutDurationMinutes, 45);
    });

    test('setDailyPhoneHours updates state', () {
      vm.setDailyPhoneHours(6);

      expect(vm.dailyPhoneHours, 6);
    });

    test('setWeeklySmallSessions updates state', () {
      vm.setWeeklySmallSessions(3);

      expect(vm.weeklySmallSessions, 3);
    });

    test('setWeeklyBigSessions updates state', () {
      vm.setWeeklyBigSessions(4);

      expect(vm.weeklyBigSessions, 4);
    });
  });

  // ── finish ─────────────────────────────────────────────────────────────────

  group('finish', () {
    void stubSuccess() {
      when(() => mockProfileRepo.updateProfile(
            any(),
            username: any(named: 'username'),
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            weeklyExerciseTargetMinutes:
                any(named: 'weeklyExerciseTargetMinutes'),
          )).thenAnswer((_) async => TestData.profile());
      when(() => mockProfileRepo.updateScreenTimeSetup(
            any(),
            dailyPhoneHours: any(named: 'dailyPhoneHours'),
            weeklySmallSessions: any(named: 'weeklySmallSessions'),
            weeklyBigSessions: any(named: 'weeklyBigSessions'),
          )).thenAnswer((_) async {});
      when(() => mockProfileRepo.updateStatus(
            any(),
            any(),
          )).thenAnswer((_) async {});
    }

    test('success (no packages): updateProfile, updateScreenTimeSetup, updateStatus called, isDone=true',
        () async {
      stubSuccess();

      await vm.finish();

      verify(() => mockProfileRepo.updateProfile(
            any(),
            username: any(named: 'username'),
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            weeklyExerciseTargetMinutes:
                any(named: 'weeklyExerciseTargetMinutes'),
          )).called(1);
      verify(() => mockProfileRepo.updateScreenTimeSetup(
            any(),
            dailyPhoneHours: any(named: 'dailyPhoneHours'),
            weeklySmallSessions: any(named: 'weeklySmallSessions'),
            weeklyBigSessions: any(named: 'weeklyBigSessions'),
          )).called(1);
      verify(() => mockProfileRepo.updateStatus(any(), UserStatus.onboarded))
          .called(1);
      expect(vm.isDone, isTrue);
    });

    test('with packages: blockingRepo.createRule called for each package',
        () async {
      stubSuccess();
      when(() => mockBlockingRepo.createRule(any()))
          .thenAnswer((_) async => TestData.blockingRule());

      await vm.finish(packages: [
        'com.instagram.android',
        'com.youtube.android',
      ]);

      verify(() => mockBlockingRepo.createRule(any())).called(2);
    });

    test('profile failure: error set, isDone=false, isSaving=false', () async {
      when(() => mockProfileRepo.updateProfile(
            any(),
            username: any(named: 'username'),
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            weeklyExerciseTargetMinutes:
                any(named: 'weeklyExerciseTargetMinutes'),
          )).thenThrow(Exception('server error'));

      await vm.finish();

      expect(vm.error, isNotNull);
      expect(vm.isDone, isFalse);
      expect(vm.isSaving, isFalse);
    });

    test('isSaving is true during async operation', () async {
      stubSuccess();
      final savingDuring = <bool>[];

      when(() => mockProfileRepo.updateProfile(
            any(),
            username: any(named: 'username'),
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            weeklyExerciseTargetMinutes:
                any(named: 'weeklyExerciseTargetMinutes'),
          )).thenAnswer((_) async {
        savingDuring.add(vm.isSaving);
        return TestData.profile();
      });

      await vm.finish();

      // isSaving is set to true before the async work begins
      expect(savingDuring, contains(true));
    });
  });
}
