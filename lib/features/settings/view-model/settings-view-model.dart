import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/profile-entity.dart';
import '../../../core/repositories/auth-repository.dart';
import '../../../core/repositories/profile-repository.dart';
import '../../../shared/logger.dart';

class SettingsViewModel extends ChangeNotifier {
  final ProfileRepository _profileRepo;
  final AuthRepository _authRepo;

  SettingsViewModel({
    required ProfileRepository profileRepo,
    required AuthRepository authRepo,
  })  : _profileRepo = profileRepo,
        _authRepo = authRepo;

  ProfileEntity? _profile;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  String? _successMessage;

  ProfileEntity? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String? get successMessage => _successMessage;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      _profile = await _profileRepo.getProfile(userId);
    } catch (e) {
      Log.error('SettingsViewModel', e);
      _error = 'Could not load profile.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateScreenTimeSetup({
    required int dailyPhoneHours,
    required int weeklySmallSessions,
    required int weeklyBigSessions,
  }) async {
    _isSaving = true;
    _error = null;
    _successMessage = null;
    notifyListeners();

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await _profileRepo.updateScreenTimeSetup(
        userId,
        dailyPhoneHours: dailyPhoneHours,
        weeklySmallSessions: weeklySmallSessions,
        weeklyBigSessions: weeklyBigSessions,
      );
      _profile = await _profileRepo.getProfile(userId);
      _successMessage = 'Screen time setup saved.';
    } catch (e) {
      Log.error('SettingsViewModel.updateScreenTimeSetup', e);
      _error = 'Could not update screen time setup.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? username,
    String? firstName,
    String? lastName,
    int? weeklyExerciseTargetMinutes,
  }) async {
    _isSaving = true;
    _error = null;
    _successMessage = null;
    notifyListeners();

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      _profile = await _profileRepo.updateProfile(
        userId,
        username: username,
        firstName: firstName,
        lastName: lastName,
        weeklyExerciseTargetMinutes: weeklyExerciseTargetMinutes,
      );
      _successMessage = 'Profile updated successfully.';
    } catch (e) {
      Log.error('SettingsViewModel.updateProfile', e);
      _error = 'Could not update profile.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _authRepo.signOut();
    } catch (e) {
      Log.error('SettingsViewModel.signOut', e);
      _error = 'Could not sign out.';
      notifyListeners();
    }
  }

  void clearMessages() {
    _error = null;
    _successMessage = null;
    notifyListeners();
  }
}
