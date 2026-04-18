import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/exercise-entity.dart';
import '../../../core/entities/workout-plan-entity.dart';
import '../../../core/repositories/exercise-repository.dart';
import '../../../core/repositories/workout-plan-repository.dart';
import '../../../shared/logger.dart';
import '../../../shared/utils/duration-estimator.dart';
import '../model/workout-models.dart';

class WorkoutBuilderViewModel extends ChangeNotifier {
  final WorkoutPlanRepository _planRepo;
  final ExerciseRepository _exerciseRepo;
  final String Function() _getUserId;

  WorkoutBuilderViewModel({
    required WorkoutPlanRepository planRepo,
    required ExerciseRepository exerciseRepo,
    String Function()? getUserId,
  })  : _planRepo = planRepo,
        _exerciseRepo = exerciseRepo,
        _getUserId = getUserId ??
            (() => Supabase.instance.client.auth.currentUser!.id);

  // ── State ─────────────────────────────────────────────────────────────────

  String title = '';
  String description = '';
  List<int> scheduledDays = [];
  List<BuilderEntry> entries = [];
  SessionSize sessionSize = SessionSize.small;

  WorkoutPlanEntity? _editingPlan;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  bool get isEditMode => _editingPlan != null;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  bool get isValid =>
      title.trim().isNotEmpty && entries.isNotEmpty && entries.every((e) => e.isValid);

  String get durationEstimate {
    if (entries.isEmpty) return '';
    final measurements = {
      for (final e in entries) e.exercise.id: e.exercise.measurementType,
    };
    final planExercises = entries
        .map((e) => WorkoutPlanExercise(
              exerciseId: e.exercise.id,
              exerciseName: e.exercise.name,
              sets: e.sets,
              reps: e.reps,
              durationSeconds: e.durationSeconds,
              restSeconds: e.restSeconds,
              weightKg: e.weightKg,
              distanceKm: e.distanceKm,
            ))
        .toList();
    return DurationEstimator.formatEstimate(planExercises, measurements);
  }

  // ── Load (edit mode) ──────────────────────────────────────────────────────

  Future<void> loadForEdit(String planId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final plan = await _planRepo.getPlan(planId);
      if (plan == null) {
        _error = 'Plan not found.';
        return;
      }
      _editingPlan = plan;
      title = plan.title;
      description = plan.description ?? '';
      scheduledDays = List.from(plan.scheduledDays);
      sessionSize = plan.sessionSize;

      final exerciseDetails = await Future.wait(
        plan.exercises.map((e) => _exerciseRepo.getExercise(e.exerciseId)),
      );

      entries = [];
      for (int i = 0; i < plan.exercises.length; i++) {
        final planEx = plan.exercises[i];
        final detail = exerciseDetails[i];
        if (detail == null) continue;
        entries.add(BuilderEntry(
          exercise: detail,
          sets: planEx.sets,
          reps: planEx.reps,
          durationSeconds: planEx.durationSeconds,
          restSeconds: planEx.restSeconds,
          weightKg: planEx.weightKg,
          distanceKm: planEx.distanceKm,
        ));
      }
      Log.db('builder loaded for edit: ${plan.title}');
    } catch (e) {
      Log.error('WorkoutBuilderViewModel', e);
      _error = 'Could not load plan.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Entry management ──────────────────────────────────────────────────────

  void addExercise(ExerciseEntity exercise) {
    entries.add(BuilderEntry(exercise: exercise));
    notifyListeners();
  }

  void removeExercise(int index) {
    entries.removeAt(index);
    notifyListeners();
  }

  void reorderExercise(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = entries.removeAt(oldIndex);
    entries.insert(newIndex, item);
    notifyListeners();
  }

  void updateEntry(int index, BuilderEntry updated) {
    entries[index] = updated;
    notifyListeners();
  }

  void setSessionSize(SessionSize size) {
    sessionSize = size;
    notifyListeners();
  }

  // ── Scheduling ────────────────────────────────────────────────────────────

  void toggleDay(int weekday) {
    if (scheduledDays.contains(weekday)) {
      scheduledDays.remove(weekday);
    } else {
      scheduledDays.add(weekday);
      scheduledDays.sort();
    }
    notifyListeners();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<WorkoutPlanEntity?> save() async {
    if (!isValid) return null;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _getUserId();
      final exercises = entries
          .map((e) => WorkoutPlanExercise(
                exerciseId: e.exercise.id,
                exerciseName: e.exercise.name,
                sets: e.sets,
                reps: e.reps,
                durationSeconds: e.durationSeconds,
                restSeconds: e.restSeconds,
                weightKg: e.weightKg,
                distanceKm: e.distanceKm,
              ))
          .toList();

      if (isEditMode) {
        final updated = _editingPlan!.copyWith(
          title: title.trim(),
          description: description.trim().isEmpty ? null : description.trim(),
          scheduledDays: scheduledDays,
          exercises: exercises,
          sessionSize: sessionSize,
          updatedAt: DateTime.now(),
        );
        final result = await _planRepo.updatePlan(updated);
        Log.db('plan updated ✓');
        return result;
      } else {
        final newPlan = WorkoutPlanEntity(
          id: '',
          userId: userId,
          title: title.trim(),
          description: description.trim().isEmpty ? null : description.trim(),
          source: WorkoutSource.manual,
          scheduledDays: scheduledDays,
          exercises: exercises,
          sessionSize: sessionSize,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final result = await _planRepo.createPlan(newPlan);
        Log.db('plan created ✓');
        return result;
      }
    } catch (e) {
      Log.error('WorkoutBuilderViewModel', e);
      _error = 'Could not save plan. Please try again.';
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void setTitleFromController(String value) {
    title = value;
    notifyListeners();
  }

  void setDescriptionFromController(String value) {
    description = value;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
