import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/core/entities/enums.dart';
import 'package:nashaat/features/workout/view-model/exercise-library-view-model.dart';

import '../../../helpers/mock_repositories.dart';
import '../../../helpers/test_data.dart';

void main() {
  late MockExerciseRepository mockExerciseRepo;
  late ExerciseLibraryViewModel vm;

  setUp(() {
    mockExerciseRepo = MockExerciseRepository();
    vm = ExerciseLibraryViewModel(repo: mockExerciseRepo);
  });

  tearDown(() => vm.dispose());

  // ── Initial state ──────────────────────────────────────────────────────────

  group('initial state', () {
    test('exercises is empty', () {
      expect(vm.exercises, isEmpty);
    });

    test('isLoading is false', () {
      expect(vm.isLoading, isFalse);
    });
  });

  // ── loadAll ────────────────────────────────────────────────────────────────

  group('loadAll', () {
    test('success: exercises populated', () async {
      final exercises = [
        TestData.exercise(id: 'ex1', name: 'Push-up'),
        TestData.exercise(id: 'ex2', name: 'Squat'),
      ];
      when(() => mockExerciseRepo.getAllExercises())
          .thenAnswer((_) async => exercises);

      await vm.loadAll();

      expect(vm.exercises.length, 2);
      expect(vm.error, isNull);
    });

    test('failure: error set', () async {
      when(() => mockExerciseRepo.getAllExercises())
          .thenThrow(Exception('load failed'));

      await vm.loadAll();

      expect(vm.error, isNotNull);
    });
  });

  // ── onSearchChanged ────────────────────────────────────────────────────────

  group('onSearchChanged', () {
    setUp(() async {
      when(() => mockExerciseRepo.getAllExercises()).thenAnswer((_) async => [
            TestData.exercise(id: 'ex1', name: 'Push-up'),
            TestData.exercise(id: 'ex2', name: 'Squat'),
            TestData.exercise(id: 'ex3', name: 'pull-down'),
          ]);
      await vm.loadAll();
    });

    test('filters by name (case-insensitive)', () async {
      vm.onSearchChanged('push');
      // wait for debounce
      await Future.delayed(const Duration(milliseconds: 350));

      expect(vm.exercises.length, 1);
      expect(vm.exercises.first.name, 'Push-up');
    });

    test('partial match works', () async {
      vm.onSearchChanged('ull');
      await Future.delayed(const Duration(milliseconds: 350));

      expect(vm.exercises.length, 1);
      expect(vm.exercises.first.name, 'pull-down');
    });

    test('empty query returns all', () async {
      vm.onSearchChanged('push');
      await Future.delayed(const Duration(milliseconds: 350));
      vm.onSearchChanged('');
      await Future.delayed(const Duration(milliseconds: 350));

      expect(vm.exercises.length, 3);
    });
  });

  // ── setMuscleGroup ─────────────────────────────────────────────────────────

  group('setMuscleGroup', () {
    setUp(() async {
      when(() => mockExerciseRepo.getAllExercises()).thenAnswer((_) async => [
            TestData.exercise(
                id: 'ex1', name: 'Push-up', muscleGroups: ['chest', 'triceps']),
            TestData.exercise(
                id: 'ex2', name: 'Squat', muscleGroups: ['quads', 'glutes']),
          ]);
      await vm.loadAll();
    });

    test('filters by muscle group', () {
      vm.setMuscleGroup('chest');

      expect(vm.exercises.length, 1);
      expect(vm.exercises.first.name, 'Push-up');
    });

    test('null muscle group returns all', () {
      vm.setMuscleGroup('chest');
      vm.setMuscleGroup(null);

      expect(vm.exercises.length, 2);
    });
  });

  // ── setDifficulty ──────────────────────────────────────────────────────────

  group('setDifficulty', () {
    setUp(() async {
      when(() => mockExerciseRepo.getAllExercises()).thenAnswer((_) async => [
            TestData.exercise(
                id: 'ex1',
                name: 'Easy',
                difficultyLevel: DifficultyLevel.easy),
            TestData.exercise(
                id: 'ex2',
                name: 'Hard',
                difficultyLevel: DifficultyLevel.hard),
          ]);
      await vm.loadAll();
    });

    test('filters by difficulty', () {
      vm.setDifficulty(DifficultyLevel.easy);

      expect(vm.exercises.length, 1);
      expect(vm.exercises.first.name, 'Easy');
    });

    test('null difficulty returns all', () {
      vm.setDifficulty(DifficultyLevel.easy);
      vm.setDifficulty(null);

      expect(vm.exercises.length, 2);
    });
  });

  // ── combined filters ───────────────────────────────────────────────────────

  group('combined filters', () {
    setUp(() async {
      when(() => mockExerciseRepo.getAllExercises()).thenAnswer((_) async => [
            TestData.exercise(
              id: 'ex1',
              name: 'Push-up',
              muscleGroups: ['chest'],
              difficultyLevel: DifficultyLevel.easy,
            ),
            TestData.exercise(
              id: 'ex2',
              name: 'Chest Press',
              muscleGroups: ['chest'],
              difficultyLevel: DifficultyLevel.hard,
            ),
            TestData.exercise(
              id: 'ex3',
              name: 'Squat',
              muscleGroups: ['quads'],
              difficultyLevel: DifficultyLevel.easy,
            ),
          ]);
      await vm.loadAll();
    });

    test('search + muscleGroup combined', () async {
      vm.setMuscleGroup('chest');
      vm.onSearchChanged('push');
      await Future.delayed(const Duration(milliseconds: 350));

      expect(vm.exercises.length, 1);
      expect(vm.exercises.first.name, 'Push-up');
    });
  });

  // ── clearFilters ───────────────────────────────────────────────────────────

  group('clearFilters', () {
    setUp(() async {
      when(() => mockExerciseRepo.getAllExercises()).thenAnswer((_) async => [
            TestData.exercise(id: 'ex1', name: 'A', muscleGroups: ['chest']),
            TestData.exercise(id: 'ex2', name: 'B', muscleGroups: ['back']),
          ]);
      await vm.loadAll();
    });

    test('resets to all exercises after filters applied', () {
      vm.setMuscleGroup('chest');
      expect(vm.exercises.length, 1);

      vm.clearFilters();

      expect(vm.exercises.length, 2);
    });
  });

  // ── availableMuscleGroups ──────────────────────────────────────────────────

  group('availableMuscleGroups', () {
    test('deduplicates and sorts', () async {
      when(() => mockExerciseRepo.getAllExercises()).thenAnswer((_) async => [
            TestData.exercise(
                id: 'ex1',
                name: 'A',
                muscleGroups: ['chest', 'triceps']),
            TestData.exercise(
                id: 'ex2',
                name: 'B',
                muscleGroups: ['back', 'chest']),
          ]);
      await vm.loadAll();

      final groups = vm.availableMuscleGroups;

      expect(groups, ['back', 'chest', 'triceps']);
    });
  });
}
