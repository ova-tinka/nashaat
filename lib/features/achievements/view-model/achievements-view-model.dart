import 'package:flutter/foundation.dart';

import '../../../core/entities/achievement-entity.dart';
import '../../../core/repositories/achievement-repository.dart';
import '../../../shared/logger.dart';
import '../model/achievement-progress-model.dart';

class AchievementsViewModel extends ChangeNotifier {
  final String userId;
  final AchievementRepository _achievementRepo;

  AchievementsViewModel({
    required this.userId,
    required AchievementRepository achievementRepo,
  }) : _achievementRepo = achievementRepo;

  List<AchievementProgressModel> _achievements = [];
  bool _isLoading = false;
  String? _error;

  List<AchievementProgressModel> get achievements =>
      List.unmodifiable(_achievements);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _achievementRepo.getDefinitions(activeOnly: true),
        _achievementRepo.getUserAchievements(userId),
      ]);
      final definitions = results[0] as List<AchievementDefinitionEntity>;
      final userAchievements = results[1] as List<UserAchievementEntity>;
      final progressByAchievementId = {
        for (final achievement in userAchievements)
          achievement.achievementId: achievement,
      };

      _achievements = definitions
          .map(
            (definition) => AchievementProgressModel(
              definition: definition,
              userAchievement: progressByAchievementId[definition.id],
            ),
          )
          .toList();
      Log.db('loaded ${_achievements.length} active achievement(s)');
    } catch (e) {
      Log.error('AchievementsViewModel', e);
      _error = 'Could not load achievements. Pull down to retry.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
