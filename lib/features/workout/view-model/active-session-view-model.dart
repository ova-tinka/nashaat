import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/achievement-entity.dart';
import '../../../core/entities/profile-entity.dart';
import '../../../core/entities/workout-completion-result.dart';
import '../../../core/entities/workout-log-entity.dart';
import '../../../core/entities/workout-plan-entity.dart';
import '../../../core/repositories/achievement-repository.dart';
import '../../../core/repositories/profile-repository.dart';
import '../../../core/repositories/workout-log-repository.dart';
import '../../../shared/logger.dart';
import '../model/workout-models.dart';

class ActiveSessionViewModel extends ChangeNotifier {
  final WorkoutPlanEntity plan;
  final WorkoutLogRepository _logRepo;
  final ProfileRepository _profileRepo;
  final AchievementRepository _achievementRepo;
  final SessionMode mode;
  final String Function() _getUserId;

  ActiveSessionViewModel({
    required this.plan,
    required this.mode,
    required WorkoutLogRepository logRepo,
    required ProfileRepository profileRepo,
    required AchievementRepository achievementRepo,
    String Function()? getUserId,
  }) : _logRepo = logRepo,
       _profileRepo = profileRepo,
       _achievementRepo = achievementRepo,
       _getUserId =
           getUserId ?? (() => Supabase.instance.client.auth.currentUser!.id) {
    _initSets();
  }

  int _exerciseIndex = 0;
  int _setIndex = 0;
  ActiveSessionStatus _status = ActiveSessionStatus.idle;
  int _elapsedSeconds = 0;
  int _restCountdown = 0;
  Timer? _timer;
  Timer? _restTimer;

  final List<List<bool>> _setCompletions = [];
  bool _isSaving = false;
  bool _isStartingServerSession = false;
  Future<void>? _initialization;
  String? _serverSessionId;
  String? _error;
  int _earnedMinutes = 0;
  int _pointsEarned = 0;
  int _pointsTotal = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  ProfileEntity? _profile;
  List<UserAchievementEntity> _userAchievements = [];
  List<UnlockedAchievementEntity> _newlyUnlockedAchievements = [];

  ActiveSessionStatus get status => _status;
  int get exerciseIndex => _exerciseIndex;
  int get setIndex => _setIndex;
  int get elapsedSeconds => _elapsedSeconds;
  int get restCountdown => _restCountdown;
  bool get isSaving => _isSaving;
  bool get isStartingServerSession => _isStartingServerSession;
  bool get isServerSessionReady => _serverSessionId != null;
  String? get error => _error;
  int get earnedMinutes => _earnedMinutes;
  int get pointsEarned => _pointsEarned;
  int get pointsTotal => _pointsTotal;
  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  ProfileEntity? get profile => _profile;
  List<UserAchievementEntity> get userAchievements =>
      List.unmodifiable(_userAchievements);
  List<UnlockedAchievementEntity> get newlyUnlockedAchievements =>
      List.unmodifiable(_newlyUnlockedAchievements);
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

  void _initSets() {
    for (final e in plan.exercises) {
      _setCompletions.add(List.filled(e.sets, false));
    }
    _startSessionTimer();
  }

  Future<void> initialize() {
    if (_serverSessionId != null) return Future<void>.value();
    if (_initialization != null) return _initialization!;
    _initialization = _startServerSession();
    return _initialization!;
  }

  Future<void> _startServerSession() async {
    _isStartingServerSession = true;
    _error = null;
    notifyListeners();
    try {
      final session = await _logRepo.startSession(
        plan.id.isEmpty ? null : plan.id,
      );
      _serverSessionId = session.id;
    } catch (e) {
      Log.error('ActiveSessionViewModel.startSession', e);
      _error = 'Could not start the workout. Please try again.';
    } finally {
      _isStartingServerSession = false;
      if (_serverSessionId == null) _initialization = null;
      notifyListeners();
    }
  }

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
        return;
      }
    } else {
      _setIndex = 0;
      _exerciseIndex++;
      if (_exerciseIndex >= plan.exercises.length) {
        _finishSession();
        return;
      } else if (mode == SessionMode.guided && restSeconds > 0) {
        _startRestCountdown(restSeconds);
        return;
      }
    }
    notifyListeners();
  }

  void skipCurrentSet() => completeCurrentSet();

  void skipRest() {
    if (_status != ActiveSessionStatus.resting) return;
    _restTimer?.cancel();
    _restCountdown = 0;
    _status = ActiveSessionStatus.running;
    notifyListeners();
  }

  void toggleSet(int exerciseIdx, int setIdx) {
    if (exerciseIdx >= _setCompletions.length) return;
    if (setIdx >= _setCompletions[exerciseIdx].length) return;
    _setCompletions[exerciseIdx][setIdx] =
        !_setCompletions[exerciseIdx][setIdx];
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
      _finishSession();
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
    _finishSession();
  }

  void _finishSession() {
    _timer?.cancel();
    _restTimer?.cancel();
    _status = ActiveSessionStatus.completed;
    notifyListeners();
  }

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

  Future<void> saveSession() async {
    if (_isSaving) return;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await initialize();
      final sessionId = _serverSessionId;
      if (sessionId == null) {
        throw StateError('Workout server session has not started');
      }

      final completedExercises = <CompletedExercise>[];
      for (int i = 0; i < plan.exercises.length; i++) {
        final ex = plan.exercises[i];
        final completedSets = i < _setCompletions.length
            ? _setCompletions[i].where((s) => s).length
            : 0;
        if (completedSets == 0) continue;
        completedExercises.add(
          CompletedExercise(
            exerciseId: ex.exerciseId,
            exerciseName: ex.exerciseName,
            setsCompleted: completedSets,
            repsCompleted: ex.reps,
            durationSeconds: ex.durationSeconds,
            weightKg: ex.weightKg,
            distanceKm: ex.distanceKm,
          ),
        );
      }

      final result = await _logRepo.completeSession(
        sessionId: sessionId,
        completedExercises: completedExercises,
      );
      _applyCompletionResult(result);

      // These are display refreshes only. The completion RPC already committed
      // the workout, rewards, balance, and achievement unlocks atomically.
      try {
        final userId = _getUserId();
        final refreshedData = await Future.wait([
          _profileRepo.getProfile(userId),
          _achievementRepo.getUserAchievements(userId),
        ]);
        _profile = refreshedData[0] as ProfileEntity?;
        _userAchievements = refreshedData[1] as List<UserAchievementEntity>;
      } catch (e) {
        Log.error('ActiveSessionViewModel.refreshAfterCompletion', e);
      }

      Log.db('session saved ✓ earned ${result.earnedScreenTimeMinutes} min');
    } catch (e) {
      Log.error('ActiveSessionViewModel.completeSession', e);
      _error = 'Could not save session. Please try again.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _applyCompletionResult(WorkoutCompletionResult result) {
    _earnedMinutes = result.earnedScreenTimeMinutes;
    _pointsEarned = result.pointsEarned;
    _pointsTotal = result.pointsTotal;
    _currentStreak = result.currentStreak;
    _longestStreak = result.longestStreak;
    _newlyUnlockedAchievements = result.newlyUnlockedAchievements;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }
}
