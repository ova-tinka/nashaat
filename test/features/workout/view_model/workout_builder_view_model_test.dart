import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/core/entities/enums.dart';
import 'package:nashaat/core/entities/workout-plan-entity.dart';
import 'package:nashaat/features/workout/view-model/workout-builder-view-model.dart';

import '../../../helpers/mock_repositories.dart';
import '../../../helpers/test_data.dart';

void main() {
  late MockWorkoutPlanRepository mockPlanRepo;
  late MockExerciseRepository mockExerciseRepo;
  late WorkoutBuilderViewModel vm;

  setUpAll(() {
    registerFallbackValue(TestData.workoutPlan());
  });

  setUp(() {
    mockPlanRepo = MockWorkoutPlanRepository();
    mockExerciseRepo = MockExerciseRepository();
    vm = WorkoutBuilderViewModel(
      planRepo: mockPlanRepo,
      exerciseRepo: mockExerciseRepo,
      getUserId: () => 'u1',
    );
  });

  tearDown(() => vm.dispose());

  // ── isValid ────────────────────────────────────────────────────────────────

  group('isValid', () {
    test('false when title is empty', () {
      expect(vm.isValid, isFalse);
    });

    test('false with title but no entries', () {
      vm.title = 'My Plan';
      expect(vm.isValid, isFalse);
    });

    test('true with title and a valid entry', () {
      vm.title = 'My Plan';
      vm.addExercise(TestData.exercise(
        measurementType: ExerciseMeasurement.repsOnly,
      ));
      expect(vm.isValid, isTrue);
    });
  });

  // ── addExercise / removeExercise ───────────────────────────────────────────

  group('addExercise', () {
    test('appends a BuilderEntry', () {
      vm.addExercise(TestData.exercise());

      expect(vm.entries.length, 1);
      expect(vm.entries.first.exercise.id, 'ex1');
    });
  });

  group('removeExercise', () {
    test('removes entry by index', () {
      vm.addExercise(TestData.exercise(id: 'ex1', name: 'Push-up'));
      vm.addExercise(TestData.exercise(id: 'ex2', name: 'Squat'));

      vm.removeExercise(0);

      expect(vm.entries.length, 1);
      expect(vm.entries.first.exercise.id, 'ex2');
    });
  });

  // ── reorderExercise ────────────────────────────────────────────────────────

  group('reorderExercise', () {
    setUp(() {
      vm.addExercise(TestData.exercise(id: 'ex1', name: 'A'));
      vm.addExercise(TestData.exercise(id: 'ex2', name: 'B'));
      vm.addExercise(TestData.exercise(id: 'ex3', name: 'C'));
    });

    test('moves item from low index to high index (0 → 2)', () {
      // oldIndex=0 newIndex=2: item A should end up at index 1
      vm.reorderExercise(0, 2);

      expect(vm.entries[0].exercise.id, 'ex2');
      expect(vm.entries[1].exercise.id, 'ex1');
      expect(vm.entries[2].exercise.id, 'ex3');
    });

    test('moves item from high index to low index (2 → 0)', () {
      vm.reorderExercise(2, 0);

      expect(vm.entries[0].exercise.id, 'ex3');
      expect(vm.entries[1].exercise.id, 'ex1');
      expect(vm.entries[2].exercise.id, 'ex2');
    });
  });

  // ── toggleDay ─────────────────────────────────────────────────────────────

  group('toggleDay', () {
    test('adds a weekday that was not present', () {
      vm.toggleDay(1);

      expect(vm.scheduledDays, contains(1));
    });

    test('removes a weekday that was already present', () {
      vm.toggleDay(1);
      vm.toggleDay(1);

      expect(vm.scheduledDays, isNot(contains(1)));
    });

    test('scheduledDays is sorted after adding days out of order', () {
      vm.toggleDay(5);
      vm.toggleDay(1);
      vm.toggleDay(3);

      expect(vm.scheduledDays, [1, 3, 5]);
    });
  });

  // ── setSessionSize ─────────────────────────────────────────────────────────

  group('setSessionSize', () {
    test('updates sessionSize', () {
      expect(vm.sessionSize, SessionSize.small);

      vm.setSessionSize(SessionSize.big);

      expect(vm.sessionSize, SessionSize.big);
    });
  });

  // ── save ──────────────────────────────────────────────────────────────────

  group('save', () {
    test('returns null and does not call repo when isValid is false', () async {
      final result = await vm.save();

      expect(result, isNull);
      verifyNever(() => mockPlanRepo.createPlan(any()));
    });

    test('create new plan success: calls createPlan, returns plan', () async {
      final savedPlan = TestData.workoutPlan(id: 'new-plan');
      when(() => mockPlanRepo.createPlan(any()))
          .thenAnswer((_) async => savedPlan);

      vm.title = 'New Plan';
      vm.addExercise(TestData.exercise(
        measurementType: ExerciseMeasurement.repsOnly,
      ));

      final result = await vm.save();

      expect(result, isNotNull);
      expect(result!.id, 'new-plan');
      verify(() => mockPlanRepo.createPlan(any())).called(1);
    });

    test('create plan captures correct userId', () async {
      final savedPlan = TestData.workoutPlan();
      WorkoutPlanEntity? capturedPlan;
      when(() => mockPlanRepo.createPlan(any())).thenAnswer((inv) async {
        capturedPlan = inv.positionalArguments.first as WorkoutPlanEntity;
        return savedPlan;
      });

      vm.title = 'Plan';
      vm.addExercise(TestData.exercise(
        measurementType: ExerciseMeasurement.repsOnly,
      ));
      await vm.save();

      expect(capturedPlan?.userId, 'u1');
      expect(capturedPlan?.title, 'Plan');
    });

    test('update plan success: calls updatePlan, not createPlan', () async {
      final existingPlan = TestData.workoutPlan();
      when(() => mockPlanRepo.getPlan(any()))
          .thenAnswer((_) async => existingPlan);
      when(() => mockExerciseRepo.getExercise(any()))
          .thenAnswer((_) async =>
              TestData.exercise(measurementType: ExerciseMeasurement.repsOnly));
      when(() => mockPlanRepo.updatePlan(any()))
          .thenAnswer((_) async => existingPlan);

      await vm.loadForEdit('plan1');

      final result = await vm.save();

      expect(result, isNotNull);
      verify(() => mockPlanRepo.updatePlan(any())).called(1);
      verifyNever(() => mockPlanRepo.createPlan(any()));
    });

    test('failure: sets error, returns null', () async {
      when(() => mockPlanRepo.createPlan(any()))
          .thenThrow(Exception('server error'));

      vm.title = 'Plan';
      vm.addExercise(TestData.exercise(
        measurementType: ExerciseMeasurement.repsOnly,
      ));

      final result = await vm.save();

      expect(result, isNull);
      expect(vm.error, isNotNull);
    });
  });

  // ── loadForEdit ────────────────────────────────────────────────────────────

  group('loadForEdit', () {
    test('success: title, description, scheduledDays, sessionSize, entries populated',
        () async {
      final plan = TestData.workoutPlan(
        title: 'Loaded Plan',
        scheduledDays: [1, 3],
        sessionSize: SessionSize.big,
        exercises: [
          TestData.planExercise(exerciseId: 'ex1'),
        ],
      );
      when(() => mockPlanRepo.getPlan(any())).thenAnswer((_) async => plan);
      when(() => mockExerciseRepo.getExercise(any()))
          .thenAnswer((_) async => TestData.exercise(
                measurementType: ExerciseMeasurement.repsOnly,
              ));

      await vm.loadForEdit('plan1');

      expect(vm.title, 'Loaded Plan');
      expect(vm.scheduledDays, [1, 3]);
      expect(vm.sessionSize, SessionSize.big);
      expect(vm.entries.length, 1);
      expect(vm.isEditMode, isTrue);
    });

    test('plan not found: sets error', () async {
      when(() => mockPlanRepo.getPlan(any())).thenAnswer((_) async => null);

      await vm.loadForEdit('nonexistent');

      expect(vm.error, isNotNull);
    });
  });
}
