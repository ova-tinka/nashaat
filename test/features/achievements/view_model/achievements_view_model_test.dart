import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/core/entities/achievement-entity.dart';
import 'package:nashaat/core/entities/enums.dart';
import 'package:nashaat/features/achievements/model/achievement-progress-model.dart';
import 'package:nashaat/features/achievements/view-model/achievements-view-model.dart';

import '../../../helpers/mock_repositories.dart';

void main() {
  late MockAchievementRepository achievementRepo;
  late AchievementsViewModel viewModel;

  setUp(() {
    achievementRepo = MockAchievementRepository();
    viewModel = AchievementsViewModel(
      userId: 'user-1',
      achievementRepo: achievementRepo,
    );
  });

  tearDown(() => viewModel.dispose());

  test(
    'shows every active definition and merges available user progress',
    () async {
      final definitions = [
        _definition(id: 'first', name: 'First Step', target: 1),
        _definition(id: 'ten', name: 'Workout Ten', target: 10),
        _definition(id: 'social', name: 'Friendly Start', target: 1),
      ];
      when(
        () => achievementRepo.getDefinitions(activeOnly: true),
      ).thenAnswer((_) async => definitions);
      when(() => achievementRepo.getUserAchievements('user-1')).thenAnswer(
        (_) async => [
          _userAchievement(
            achievementId: 'first',
            progress: 1,
            unlockedAt: DateTime.utc(2026, 4, 18),
          ),
          _userAchievement(achievementId: 'ten', progress: 6),
        ],
      );

      await viewModel.load();

      expect(viewModel.achievements, hasLength(3));
      expect(
        viewModel.achievements[0].status,
        AchievementDisplayStatus.unlocked,
      );
      expect(
        viewModel.achievements[1].status,
        AchievementDisplayStatus.inProgress,
      );
      expect(viewModel.achievements[1].progressLabel, '6 / 10');
      expect(viewModel.achievements[2].status, AchievementDisplayStatus.locked);
      expect(viewModel.achievements[2].progress, 0);
    },
  );

  test('sets an error when achievement loading fails', () async {
    when(
      () => achievementRepo.getDefinitions(activeOnly: true),
    ).thenThrow(Exception('database unavailable'));
    when(
      () => achievementRepo.getUserAchievements('user-1'),
    ).thenAnswer((_) async => []);

    await viewModel.load();

    expect(viewModel.error, isNotNull);
    expect(viewModel.isLoading, isFalse);
  });
}

AchievementDefinitionEntity _definition({
  required String id,
  required String name,
  required int target,
}) {
  final now = DateTime.utc(2026, 4, 18);
  return AchievementDefinitionEntity(
    id: id,
    code: id,
    name: name,
    description: 'Description for $name',
    category: AchievementCategory.workout,
    criteria: AchievementCriteria.qualifyingWorkoutCount,
    targetValue: target,
    rewardType: RewardType.points,
    rewardAmount: 50,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

UserAchievementEntity _userAchievement({
  required String achievementId,
  required int progress,
  DateTime? unlockedAt,
}) {
  final now = DateTime.utc(2026, 4, 18);
  return UserAchievementEntity(
    id: 'user-$achievementId',
    userId: 'user-1',
    achievementId: achievementId,
    progress: progress,
    unlockedAt: unlockedAt,
    createdAt: now,
    updatedAt: now,
  );
}
