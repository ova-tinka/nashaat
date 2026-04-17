import 'package:flutter/foundation.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/workout-plan-entity.dart';
import '../../../core/repositories/profile-repository.dart';
import '../../../core/repositories/workout-plan-repository.dart';
import '../../../shared/logger.dart';

class WorkoutHubViewModel extends ChangeNotifier {
  final WorkoutPlanRepository _repo;
  final ProfileRepository _profileRepo;
  final String userId;

  WorkoutHubViewModel({
    required this.userId,
    required WorkoutPlanRepository repo,
    required ProfileRepository profileRepo,
  })  : _repo = repo,
        _profileRepo = profileRepo;

  List<WorkoutPlanEntity> _plans = [];
  bool _isLoading = false;
  String? _error;
  SubscriptionTier _tier = SubscriptionTier.free;

  List<WorkoutPlanEntity> get plans => List.unmodifiable(_plans);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isVip => _tier == SubscriptionTier.vip;

  Future<void> loadPlans() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repo.getUserPlans(userId),
        _profileRepo.getProfile(userId),
      ]);
      _plans = results[0] as List<WorkoutPlanEntity>;
      _tier = (results[1] as dynamic).subscriptionTier as SubscriptionTier;
      Log.db('hub: ${_plans.length} plans loaded, tier=$_tier');
    } catch (e) {
      Log.error('WorkoutHubViewModel', e);
      _error = 'Could not load workout plans.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deletePlan(String planId) async {
    try {
      await _repo.deletePlan(planId);
      _plans.removeWhere((p) => p.id == planId);
      notifyListeners();
    } catch (e) {
      Log.error('WorkoutHubViewModel', e);
      _error = 'Could not delete plan.';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
