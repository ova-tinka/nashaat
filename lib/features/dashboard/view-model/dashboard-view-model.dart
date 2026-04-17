import 'package:flutter/foundation.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/profile-entity.dart';
import '../../../core/entities/screen-time-transaction-entity.dart';
import '../../../core/entities/workout-log-entity.dart';
import '../../../core/repositories/profile-repository.dart';
import '../../../core/repositories/screen-time-transaction-repository.dart';
import '../../../core/repositories/workout-log-repository.dart';
import '../../../shared/logger.dart';
import '../../../shared/utils/week-helper.dart';

class DashboardViewModel extends ChangeNotifier {
  final ProfileRepository _profileRepo;
  final WorkoutLogRepository _logRepo;
  final ScreenTimeTransactionRepository _txnRepo;
  final String userId;

  DashboardViewModel({
    required this.userId,
    required ProfileRepository profileRepo,
    required WorkoutLogRepository logRepo,
    required ScreenTimeTransactionRepository txnRepo,
  })  : _profileRepo = profileRepo,
        _logRepo = logRepo,
        _txnRepo = txnRepo;

  ProfileEntity? _profile;
  List<WorkoutLogEntity> _weeklyLogs = [];
  List<ScreenTimeTransactionEntity> _recentTransactions = [];
  bool _isLoading = false;
  String? _error;

  // ── Public getters ────────────────────────────────────────────────────────

  ProfileEntity? get profile => _profile;
  List<WorkoutLogEntity> get weeklyLogs => List.unmodifiable(_weeklyLogs);
  bool get isLoading => _isLoading;
  String? get error => _error;

  String get displayName =>
      _profile?.username ??
      _profile?.firstName ??
      _profile?.email.split('@').first ??
      'Athlete';

  int get streakCount => _profile?.streakCount ?? 0;
  int get screenTimeBalanceMinutes => _profile?.screenTimeBalanceMinutes ?? 0;

  int get weeklyEarnedMinutes {
    final start = WeekHelper.weekStart(DateTime.now());
    return _recentTransactions
        .where((t) =>
            t.transactionType == TransactionType.earned &&
            t.createdAt.isAfter(start))
        .fold(0, (sum, t) => sum + t.amountMinutes);
  }

  int get weeklySpentMinutes {
    final start = WeekHelper.weekStart(DateTime.now());
    return _recentTransactions
        .where((t) =>
            (t.transactionType == TransactionType.spent ||
                t.transactionType == TransactionType.penalty) &&
            t.createdAt.isAfter(start))
        .fold(0, (sum, t) => sum + t.amountMinutes.abs());
  }

  int get weeklySessionsCompleted => _weeklyLogs.length;

  int get weeklyMinutesTrained =>
      _weeklyLogs.fold(0, (sum, l) => sum + l.durationMinutes);

  int get weeklyTargetMinutes =>
      _profile?.weeklyExerciseTargetMinutes ?? 120;

  double get weeklyProgress {
    if (weeklyTargetMinutes == 0) return 0;
    return (weeklyMinutesTrained / weeklyTargetMinutes).clamp(0.0, 1.0);
  }

  String get goalStatus {
    final p = weeklyProgress;
    if (p >= 0.9) return 'Strong';
    if (p >= 0.5) return 'Stable';
    return 'Needs Attention';
  }

  /// Returns sessions-per-day for the current week as a list of 7 doubles.
  List<double> get weeklyActivitySpots {
    final days = WeekHelper.currentWeekDays();
    return days.map((day) {
      return _weeklyLogs
          .where((l) =>
              l.loggedAt.year == day.year &&
              l.loggedAt.month == day.month &&
              l.loggedAt.day == day.day)
          .length
          .toDouble();
    }).toList();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final weekStart = WeekHelper.weekStart(DateTime.now());

      final results = await Future.wait([
        _profileRepo.getProfile(userId),
        _logRepo.getUserLogs(userId, from: weekStart),
        _txnRepo.getUserTransactions(userId, limit: 50),
      ]);

      _profile = results[0] as ProfileEntity?;
      _weeklyLogs = results[1] as List<WorkoutLogEntity>;
      _recentTransactions =
          results[2] as List<ScreenTimeTransactionEntity>;

      Log.db('dashboard loaded: ${_weeklyLogs.length} sessions this week');
    } catch (e) {
      Log.error('DashboardViewModel', e);
      _error = 'Could not load dashboard data. Pull down to retry.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
