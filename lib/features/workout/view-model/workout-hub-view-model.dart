import 'package:flutter/foundation.dart';

import '../../../core/entities/workout-plan-entity.dart';
import '../../../core/repositories/workout-plan-repository.dart';
import '../../../shared/logger.dart';

class WorkoutHubViewModel extends ChangeNotifier {
  final WorkoutPlanRepository _repo;
  final String userId;

  WorkoutHubViewModel({required this.userId, required WorkoutPlanRepository repo})
      : _repo = repo;

  List<WorkoutPlanEntity> _plans = [];
  bool _isLoading = false;
  String? _error;

  List<WorkoutPlanEntity> get plans => List.unmodifiable(_plans);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadPlans() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _plans = await _repo.getUserPlans(userId);
      Log.db('hub: ${_plans.length} plans loaded');
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
