import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/exercise-entity.dart';
import '../../../core/repositories/exercise-repository.dart';
import '../../../shared/logger.dart';

class ExerciseLibraryViewModel extends ChangeNotifier {
  final ExerciseRepository _repo;

  ExerciseLibraryViewModel({required ExerciseRepository repo}) : _repo = repo;

  List<ExerciseEntity> _allExercises = [];
  List<ExerciseEntity> _filtered = [];
  String _searchQuery = '';
  String? _selectedMuscleGroup;
  ExerciseMeasurement? _selectedMeasurement;
  ExerciseSort? _selectedSort;
  DifficultyLevel? _selectedDifficulty;
  bool _isLoading = false;
  String? _error;
  Timer? _debounce;

  List<ExerciseEntity> get exercises => List.unmodifiable(_filtered);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get selectedMuscleGroup => _selectedMuscleGroup;
  DifficultyLevel? get selectedDifficulty => _selectedDifficulty;
  ExerciseMeasurement? get selectedMeasurement => _selectedMeasurement;
  ExerciseSort? get selectedSort => _selectedSort;

  List<String> get availableMuscleGroups {
    final groups = <String>{};
    for (final e in _allExercises) {
      groups.addAll(e.muscleGroups);
    }
    return groups.toList()..sort();
  }

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allExercises = await _repo.getAllExercises();
      _applyFilters();
      Log.db('library: ${_allExercises.length} exercises');
    } catch (e) {
      Log.error('ExerciseLibraryViewModel', e);
      _error = 'Could not load exercises.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void onSearchChanged(String query) {
    _searchQuery = query;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _applyFilters();
      notifyListeners();
    });
  }

  void setMuscleGroup(String? group) {
    _selectedMuscleGroup = group;
    _applyFilters();
    notifyListeners();
  }

  void setDifficulty(DifficultyLevel? level) {
    _selectedDifficulty = level;
    _applyFilters();
    notifyListeners();
  }

  void setMeasurement(ExerciseMeasurement? measurement) {
  _selectedMeasurement = measurement;
  _applyFilters();
  notifyListeners();
}
void setSort(ExerciseSort? sort) {
  _selectedSort = sort;
  _applyFilters();
  notifyListeners();
}
 
 void clearFilters() {
  _searchQuery = '';
  _selectedMuscleGroup = null;
  _selectedDifficulty = null;
  _selectedMeasurement = null;
  _selectedSort = null;

  _applyFilters();
  notifyListeners();
}
void clearFiltersOnly() {
  _selectedMuscleGroup = null;
  _selectedDifficulty = null;
  _selectedMeasurement = null;
  _selectedSort = null;

  _applyFilters();
  notifyListeners();
}
void _applyFilters() {
  _filtered = _allExercises.where((e) {
    final matchesSearch = _searchQuery.isEmpty ||
        e.name.toLowerCase().contains(_searchQuery.toLowerCase());

    final matchesMuscle = _selectedMuscleGroup == null ||
        e.muscleGroups.any(
          (m) => m.toLowerCase() == _selectedMuscleGroup!.toLowerCase(),
        );

    final matchesDifficulty =
        _selectedDifficulty == null ||
        e.difficultyLevel == _selectedDifficulty;

    final matchesMeasurement =
        _selectedMeasurement == null ||
        e.measurementType == _selectedMeasurement;

    return matchesSearch &&
        matchesMuscle &&
        matchesDifficulty &&
        matchesMeasurement;
  }).toList();

if (_selectedSort != null) {
  _filtered.sort((a, b) {
    switch (_selectedSort!) {
      case ExerciseSort.nameAsc:
        return a.name.toLowerCase().compareTo(
              b.name.toLowerCase(),
            );

      case ExerciseSort.nameDesc:
        return b.name.toLowerCase().compareTo(
              a.name.toLowerCase(),
            );

      case ExerciseSort.difficultyAsc:
        return _difficultyValue(a.difficultyLevel)
            .compareTo(_difficultyValue(b.difficultyLevel));

      case ExerciseSort.difficultyDesc:
        return _difficultyValue(b.difficultyLevel)
            .compareTo(_difficultyValue(a.difficultyLevel));
    }
  });
}
  
}
int _difficultyValue(DifficultyLevel level) {
  switch (level) {
    case DifficultyLevel.easy:
      return 0;
    case DifficultyLevel.medium:
      return 1;
    case DifficultyLevel.hard:
      return 2;
  }
}

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
