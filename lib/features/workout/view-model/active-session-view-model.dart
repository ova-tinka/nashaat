import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/achievement-entity.dart';
import '../../../core/entities/profile-entity.dart';
import '../../../core/entities/workout-log-entity.dart';
import '../../../core/entities/workout-plan-entity.dart';
import '../../../core/repositories/profile-repository.dart';
import '../../../core/repositories/achievement-repository.dart';
import '../../../core/repositories/point-award-repository.dart';
import '../../../core/repositories/leaderboard-repository.dart';
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
  final AchievementRepository _achievementRepo;
  final PointAwardRepository _pointAwardRepo;
  final LeaderboardRepository _leaderboardRepo;
  final ScreenTimeTransactionRepository _txnRepo;
  final SessionMode mode;
  final String Function() _getUserId;

  ActiveSessionViewModel({
    required this.plan,
    required this.mode,
    required WorkoutLogRepository logRepo,
    required ProfileRepository profileRepo,
    required AchievementRepository achievementRepo,
    required PointAwardRepository pointAwardRepo,
    required LeaderboardRepository leaderboardRepo,
    required ScreenTimeTransactionRepository txnRepo,
    String Function()? getUserId,
  }) : _logRepo = logRepo,
       _profileRepo = profileRepo,
       _achievementRepo = achievementRepo,
       _pointAwardRepo = pointAwardRepo,
       _leaderboardRepo = leaderboardRepo,
       _txnRepo = txnRepo,
       _getUserId =
           getUserId ?? (() => Supabase.instance.client.auth.currentUser!.id) {
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
  int _pointsEarned = 0;
  int _pointsTotal = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  ProfileEntity? _profile;
  List<UserAchievementEntity> _userAchievements = [];
  List<UnlockedAchievementEntity> _newlyUnlockedAchievements = [];

  // ── Getters ───────────────────────────────────────────────────────────────

  ActiveSessionStatus get status => _status;
  int get exerciseIndex => _exerciseIndex;
  int get setIndex => _setIndex;
  int get elapsedSeconds => _elapsedSeconds;
  int get restCountdown => _restCountdown;
  bool get isSaving => _isSaving;
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

  // ── Init ──────────────────────────────────────────────────────────────────

  void _initSets() {
    for (final e in plan.exercises) {
      _setCompletions.add(List.filled(e.sets, false));
    }
    _startSessionTimer();
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
      final userId = _getUserId();
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

      final pointsResult = await _pointAwardRepo.awardWorkoutPoints(
        savedLog.id,
      );
      _pointsEarned = pointsResult.pointsEarned;

      // Base points and the workout log are already persisted at this point.
      // A milestone failure must not make the completed workout look unsaved;
      // the server-side operation is idempotent and can be retried safely.
      try {
        final milestoneResult = await _pointAwardRepo
            .awardStreakMilestonePoints(savedLog.id);
        Log.db(
          'streak milestone RPC result: '
          'streak_days=${milestoneResult.streakDays}, '
          'bonus_points=${milestoneResult.bonusPoints}, '
          'points_total=${milestoneResult.pointsTotal}',
        );
      } on PostgrestException catch (e, stackTrace) {
        Log.error(
          'ActiveSessionViewModel.streakMilestone',
          'PostgrestException\n'
              'code: ${e.code}\n'
              'message: ${e.message}\n'
              'details: ${e.details}\n'
              'hint: ${e.hint}\n'
              'stackTrace:\n$stackTrace',
        );
      } catch (e, stackTrace) {
        Log.error(
          'ActiveSessionViewModel.streakMilestone',
          '$e\nstackTrace:\n$stackTrace',
        );
      }

      // Supabase decides which saved workouts qualify for the weekly score.
      await _leaderboardRepo.recalculateMyWeeklyScore();

      _newlyUnlockedAchievements = await _achievementRepo
          .evaluateUserAchievements();
      final refreshedData = await Future.wait([
        _profileRepo.getProfile(userId),
        _achievementRepo.getUserAchievements(userId),
      ]);
      _profile = refreshedData[0] as ProfileEntity?;
      _userAchievements = refreshedData[1] as List<UserAchievementEntity>;

      _pointsTotal = _profile?.pointsTotal ?? pointsResult.pointsTotal;
      _currentStreak = _profile?.streakCount ?? pointsResult.currentStreak;
      _longestStreak = _profile?.longestStreak ?? pointsResult.longestStreak;

      // Record screen time transaction (only when reward > 0)
      if (earned > 0) {
        await _txnRepo.recordTransaction(
          ScreenTimeTransactionEntity(
            id: '',
            userId: userId,
            amountMinutes: earned,
            transactionType: TransactionType.earned,
            description: 'Completed: ${plan.title}',
            referenceId: savedLog.id,
            createdAt: DateTime.now(),
          ),
        );
      }

      // Update balance on profile
      final balanceProfile = _profile ?? profile;
      if (balanceProfile != null && earned > 0) {
        await _profileRepo.updateScreenTimeBalance(
          userId,
          balanceProfile.screenTimeBalanceMinutes + earned,
        );
        _profile = await _profileRepo.getProfile(userId);
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
