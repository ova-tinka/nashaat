import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/blocking-rule-entity.dart';
import '../../../core/entities/enums.dart';
import '../../../core/repositories/blocking-repository.dart';
import '../../../core/repositories/profile-repository.dart';
import '../../../infra/blocking/blocking-platform-service.dart';
import '../../../infra/permissions/permission-service.dart';
import '../../../shared/logger.dart';

const _kTotalSteps = 6;

class OnboardingViewModel extends ChangeNotifier {
  final ProfileRepository _profileRepo;
  final BlockingRepository _blockingRepo;
  final String Function() _getUserId;

  OnboardingViewModel({
    required ProfileRepository profileRepo,
    required BlockingRepository blockingRepo,
    String Function()? getUserId,
  })  : _profileRepo = profileRepo,
        _blockingRepo = blockingRepo,
        _getUserId = getUserId ??
            (() => Supabase.instance.client.auth.currentUser!.id);

  // ── State ─────────────────────────────────────────────────────────────────

  int _step = 0;
  String _username = '';
  int _daysPerWeek = 4;
  int _workoutDurationMinutes = 30;
  int _dailyPhoneHours = 8;
  int _weeklySmallSessions = 2;
  int _weeklyBigSessions = 3;
  bool _isSaving = false;
  bool _isDone = false;
  String? _error;

  int get step => _step;
  String get username => _username;
  int get daysPerWeek => _daysPerWeek;
  int get workoutDurationMinutes => _workoutDurationMinutes;
  int get dailyPhoneHours => _dailyPhoneHours;
  int get weeklySmallSessions => _weeklySmallSessions;
  int get weeklyBigSessions => _weeklyBigSessions;
  bool get isSaving => _isSaving;
  bool get isDone => _isDone;
  String? get error => _error;

  // ── Mutations ─────────────────────────────────────────────────────────────

  void setUsername(String value) {
    _username = value;
    notifyListeners();
  }

  void setDaysPerWeek(int value) {
    _daysPerWeek = value;
    notifyListeners();
  }

  void setWorkoutDurationMinutes(int value) {
    _workoutDurationMinutes = value;
    notifyListeners();
  }

  void setDailyPhoneHours(int value) {
    _dailyPhoneHours = value;
    notifyListeners();
  }

  void setWeeklySmallSessions(int value) {
    _weeklySmallSessions = value;
    notifyListeners();
  }

  void setWeeklyBigSessions(int value) {
    _weeklyBigSessions = value;
    notifyListeners();
  }

  void goNext() {
    if (_step < _kTotalSteps - 1) {
      _step++;
      notifyListeners();
    }
  }

  /// Returns true if the step was decremented, false if already at step 0.
  bool goBack() {
    if (_step > 0) {
      _step--;
      notifyListeners();
      return true;
    }
    return false;
  }

  // ── Finish ────────────────────────────────────────────────────────────────

  Future<void> finish({List<String> packages = const []}) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _getUserId();
      final weeklyTargetMinutes = _daysPerWeek * _workoutDurationMinutes;

      await _profileRepo.updateProfile(
        userId,
        username: _username.trim().isEmpty ? null : _username.trim(),
        weeklyExerciseTargetMinutes: weeklyTargetMinutes,
      );
      await _profileRepo.updateScreenTimeSetup(
        userId,
        dailyPhoneHours: _dailyPhoneHours,
        weeklySmallSessions: _weeklySmallSessions,
        weeklyBigSessions: _weeklyBigSessions,
      );

      if (packages.isNotEmpty) {
        try {
          for (final pkg in packages) {
            await _blockingRepo.createRule(BlockingRuleEntity(
              id: '',
              userId: userId,
              itemType: ItemType.app,
              itemIdentifier: pkg,
              status: RuleStatus.active,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));
          }
          final platform = BlockingPlatformService();
          final permService = PermissionService(platform);
          final perms = await permService.checkAll();
          if (!perms.isFullyGranted) {
            for (final p in perms.missing) {
              await permService.request(p);
            }
          }
        } catch (e) {
          Log.error('OnboardingViewModel.blocking', e);
        }
      }

      await _profileRepo.updateStatus(userId, UserStatus.onboarded);
      Log.auth('onboarding complete');

      _isDone = true;
      notifyListeners();
    } catch (e) {
      Log.error('OnboardingViewModel', e);
      _error = 'Could not save preferences. Please try again.';
      _isSaving = false;
      notifyListeners();
    }
  }
}
