import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/workout-log-entity.dart';
import '../../../core/entities/workout-plan-entity.dart';
import '../../../core/repositories/profile-repository.dart';
import '../../../core/repositories/screen-time-transaction-repository.dart';
import '../../../core/repositories/workout-log-repository.dart';
import '../../../core/entities/screen-time-transaction-entity.dart';
import '../../../shared/logger.dart';
import '../../../shared/utils/screen-time-economy.dart';
import '../model/workout-models.dart';

class ActiveSessionViewModel extends ChangeNotifier {
  final WorkoutPlanEntity plan;
  final WorkoutLogRepository _logRepo;
  final ProfileRepository _profileRepo;
  final ScreenTimeTransactionRepository _txnRepo;
  final SessionMode mode;

  ActiveSessionViewModel({
    required this.plan,
    required this.mode,
    required WorkoutLogRepository logRepo,
    required ProfileRepository profileRepo,
    required ScreenTimeTransactionRepository txnRepo,
  })  : _logRepo = logRepo,
        _profileRepo = profileRepo,
        _txnRepo = txnRepo {
    _initSets();
  }

  // ── State ─────────────────────────────────────────────────────────────────

  int _exerciseIndex = 0;
  int _setIndex = 0;
  ActiveSessionStatus _status = ActiveSessionStatus.idle;
  int _elapsedSeconds = 0;
  int _restCountdown = 0;
  Timer? _timer;
  Timer? _restTimer;

  final List<List<bool>> _setCompletions = [];
  bool _isSaving = false;
  String? _error;
  int _earnedMinutes = 0;

  // ── Getters ───────────────────────────────────────────────────────────────

  ActiveSessionStatus get status => _status;
  int get exerciseIndex => _exerciseIndex;
  int get setIndex => _setIndex;
  int get elapsedSeconds => _elapsedSeconds;
  int get restCountdown => _restCountdown;
  bool get isSaving => _isSaving;
  String? get error => _error;
  int get earnedMinutes => _earnedMinutes;
  List<List<bool>> get setCompletions => _setCompletions;

  WorkoutPlanExercise? get currentExercise =>
      _exerciseIndex < plan.exercises.length
          ? plan.exercises[_exerciseIndex]
          : null;

  int get totalExercises => plan.exercises.length;
  int get totalSetsForCurrent => currentExercise?.sets ?? 0;

  double get overallProgress {
    final totalSets = plan.exercises.fold(0, (sum, e) => sum + e.sets);
    if (totalSets == 0) return 0;
    final completed = _setCompletions.fold(
      0,
      (sum, sets) => sum + sets.where((s) => s).length,
    );
    return completed / totalSets;
  }

  bool get isCurrentSetDone =>
      _exerciseIndex < _setCompletions.length &&
      _setIndex < _setCompletions[_exerciseIndex].length &&
      _setCompletions[_exerciseIndex][_setIndex];

  bool get isExerciseDone =>
      _exerciseIndex < _setCompletions.length &&
      _setCompletions[_exerciseIndex].every((s) => s);

  bool get isSessionComplete => _status == ActiveSessionStatus.completed;

  // ── Init ──────────────────────────────────────────────────────────────────

  void _initSets() {
    for (final e in plan.exercises) {
      _setCompletions.add(List.filled(e.sets, false));
    }
    if (mode == SessionMode.guided) {
      _startSessionTimer();
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void completeCurrentSet() {
    if (_exerciseIndex >= _setCompletions.length) return;
    if (_setIndex >= _setCompletions[_exerciseIndex].length) return;

    _setCompletions[_exerciseIndex][_setIndex] = true;

    final ex = currentExercise;
    final restSeconds = ex?.restSeconds ?? 60;

    if (_setIndex < totalSetsForCurrent - 1) {
      _setIndex++;
      if (mode == SessionMode.guided && restSeconds > 0) {
        _startRestCountdown(restSeconds);
        return; // _startRestCountdown calls notifyListeners
      }
    } else {
      _setIndex = 0;
      _exerciseIndex++;
      if (_exerciseIndex >= plan.exercises.length) {
        _finishSession();
        return; // _finishSession calls notifyListeners
      } else if (mode == SessionMode.guided && restSeconds > 0) {
        _startRestCountdown(restSeconds);
        return;
      }
    }
    notifyListeners();
  }

  void skipCurrentSet() => completeCurrentSet();

  void toggleSet(int exerciseIdx, int setIdx) {
    if (exerciseIdx >= _setCompletions.length) return;
    if (setIdx >= _setCompletions[exerciseIdx].length) return;
    _setCompletions[exerciseIdx][setIdx] = !_setCompletions[exerciseIdx][setIdx];
    notifyListeners();
  }

  void markExerciseDone(int exerciseIdx) {
    if (exerciseIdx >= _setCompletions.length) return;
    for (int i = 0; i < _setCompletions[exerciseIdx].length; i++) {
      _setCompletions[exerciseIdx][i] = true;
    }
    _exerciseIndex = exerciseIdx + 1;
    _setIndex = 0;
    if (_exerciseIndex >= plan.exercises.length) {
      _finishSession(); // calls notifyListeners
    } else {
      notifyListeners();
    }
  }

  void markAllComplete() {
    for (final sets in _setCompletions) {
      for (int i = 0; i < sets.length; i++) {
        sets[i] = true;
      }
    }
    _finishSession(); // calls notifyListeners
  }

  void _finishSession() {
    _timer?.cancel();
    _restTimer?.cancel();
    _status = ActiveSessionStatus.completed;
    notifyListeners();
  }

  // ── Timer logic ───────────────────────────────────────────────────────────

  void _startSessionTimer() {
    _status = ActiveSessionStatus.running;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });
  }

  void _startRestCountdown(int seconds) {
    _status = ActiveSessionStatus.resting;
    _restCountdown = seconds;
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _restCountdown--;
      if (_restCountdown <= 0) {
        t.cancel();
        _status = ActiveSessionStatus.running;
      }
      notifyListeners();
    });
  }

  void pauseOrResume() {
    if (_status == ActiveSessionStatus.running) {
      _timer?.cancel();
      _status = ActiveSessionStatus.paused;
    } else if (_status == ActiveSessionStatus.paused) {
      _startSessionTimer();
    }
    notifyListeners();
  }

  // ── Persist completed session ─────────────────────────────────────────────

  Future<void> saveSession() async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final durationMinutes = (_elapsedSeconds / 60).ceil().clamp(1, 9999);

      // Reward is fixed per session size — no partial rewards.
      // Profile supplies the calculated reward based on user's phone-time setup.
      final profile = await _profileRepo.getProfile(userId);
      final earned = profile != null && profile.isScreenTimeConfigured
          ? ScreenTimeEconomy.rewardMinutes(profile, plan.sessionSize)
          : 0;

      final completedExercises = <CompletedExercise>[];
      for (int i = 0; i < plan.exercises.length; i++) {
        final ex = plan.exercises[i];
        final completedSets =
            i < _setCompletions.length ? _setCompletions[i].where((s) => s).length : 0;
        if (completedSets == 0) continue;
        completedExercises.add(CompletedExercise(
          exerciseId: ex.exerciseId,
          exerciseName: ex.exerciseName,
          setsCompleted: completedSets,
          repsCompleted: ex.reps,
          durationSeconds: ex.durationSeconds,
          weightKg: ex.weightKg,
          distanceKm: ex.distanceKm,
        ));
      }

      final log = WorkoutLogEntity(
        id: '',
        userId: userId,
        workoutPlanId: plan.id.isNotEmpty ? plan.id : null,
        durationMinutes: durationMinutes,
        earnedScreenTimeMinutes: earned,
        completedExercises: completedExercises,
        loggedAt: DateTime.now(),
      );
      final savedLog = await _logRepo.createLog(log);

      // Record screen time transaction (only when reward > 0)
      if (earned > 0) {
        await _txnRepo.recordTransaction(ScreenTimeTransactionEntity(
          id: '',
          userId: userId,
          amountMinutes: earned,
          transactionType: TransactionType.earned,
          description: 'Completed: ${plan.title}',
          referenceId: savedLog.id,
          createdAt: DateTime.now(),
        ));
      }

      // Update balance on profile
      if (profile != null && earned > 0) {
        await _profileRepo.updateScreenTimeBalance(
          userId,
          profile.screenTimeBalanceMinutes + earned,
        );
      }

      _earnedMinutes = earned;
      Log.db('session saved ✓ earned $earned min');
    } catch (e) {
      Log.error('ActiveSessionViewModel', e);
      _error = 'Could not save session. Please try again.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }
}
