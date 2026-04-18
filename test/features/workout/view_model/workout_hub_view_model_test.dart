import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/core/entities/enums.dart';
import 'package:nashaat/features/workout/view-model/workout-hub-view-model.dart';

import '../../../helpers/mock_repositories.dart';
import '../../../helpers/test_data.dart';

void main() {
  late MockWorkoutPlanRepository mockPlanRepo;
  late MockProfileRepository mockProfileRepo;
  late WorkoutHubViewModel vm;

  setUp(() {
    mockPlanRepo = MockWorkoutPlanRepository();
    mockProfileRepo = MockProfileRepository();
    vm = WorkoutHubViewModel(
      userId: 'u1',
      repo: mockPlanRepo,
      profileRepo: mockProfileRepo,
    );
  });

  tearDown(() => vm.dispose());

  // ── Initial state ──────────────────────────────────────────────────────────

  group('initial state', () {
    test('plans is empty', () {
      expect(vm.plans, isEmpty);
    });

    test('isLoading is false', () {
      expect(vm.isLoading, isFalse);
    });

    test('no error', () {
      expect(vm.error, isNull);
    });
  });

  // ── loadPlans ──────────────────────────────────────────────────────────────

  group('loadPlans', () {
    test('success: plans populated from repo', () async {
      final plans = [TestData.workoutPlan(), TestData.workoutPlan(id: 'plan2')];
      when(() => mockPlanRepo.getUserPlans(any()))
          .thenAnswer((_) async => plans);
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());

      await vm.loadPlans();

      expect(vm.plans.length, 2);
      expect(vm.error, isNull);
    });

    test('sets isVip when subscription tier is vip', () async {
      when(() => mockPlanRepo.getUserPlans(any())).thenAnswer((_) async => []);
      when(() => mockProfileRepo.getProfile(any())).thenAnswer(
          (_) async => TestData.profile(subscriptionTier: SubscriptionTier.vip));

      await vm.loadPlans();

      expect(vm.isVip, isTrue);
    });

    test('isVip is false when subscription tier is free', () async {
      when(() => mockPlanRepo.getUserPlans(any())).thenAnswer((_) async => []);
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());

      await vm.loadPlans();

      expect(vm.isVip, isFalse);
    });

    test('failure: error is set, isLoading is false', () async {
      when(() => mockPlanRepo.getUserPlans(any()))
          .thenThrow(Exception('server error'));
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());

      await vm.loadPlans();

      expect(vm.error, isNotNull);
      expect(vm.isLoading, isFalse);
    });

    test('isLoading transitions true then false', () async {
      final loadingValues = <bool>[];
      when(() => mockPlanRepo.getUserPlans(any()))
          .thenAnswer((_) async => []);
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());

      vm.addListener(() => loadingValues.add(vm.isLoading));
      await vm.loadPlans();

      expect(loadingValues, containsAllInOrder([true, false]));
    });
  });

  // ── deletePlan ─────────────────────────────────────────────────────────────

  group('deletePlan', () {
    setUp(() {
      when(() => mockPlanRepo.getUserPlans(any()))
          .thenAnswer((_) async => [TestData.workoutPlan()]);
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());
    });

    test('success: plan removed from list', () async {
      when(() => mockPlanRepo.deletePlan(any())).thenAnswer((_) async {});

      await vm.loadPlans();
      expect(vm.plans.length, 1);

      await vm.deletePlan('plan1');

      expect(vm.plans, isEmpty);
    });

    test('failure: error set, plan not removed', () async {
      when(() => mockPlanRepo.deletePlan(any()))
          .thenThrow(Exception('delete failed'));

      await vm.loadPlans();
      await vm.deletePlan('plan1');

      expect(vm.error, isNotNull);
      expect(vm.plans.length, 1);
    });
  });

  // ── clearError ─────────────────────────────────────────────────────────────

  group('clearError', () {
    test('clears the error message', () async {
      when(() => mockPlanRepo.getUserPlans(any()))
          .thenThrow(Exception('fail'));
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());

      await vm.loadPlans();
      expect(vm.error, isNotNull);

      vm.clearError();

      expect(vm.error, isNull);
    });
  });
}
