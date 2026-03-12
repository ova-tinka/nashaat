import '../entities/enums.dart';
import '../entities/profile-entity.dart';

abstract class ProfileRepository {
  Future<ProfileEntity?> getProfile(String userId);

  Future<ProfileEntity> updateProfile(
    String userId, {
    String? username,
    String? firstName,
    String? lastName,
    int? weeklyExerciseTargetMinutes,
    String? fcmToken,
    String? avatarMediaId,
  });

  Future<void> updateStatus(String userId, UserStatus status);

  Future<void> updateScreenTimeBalance(String userId, int balanceMinutes);

  Future<void> updateStreak(
    String userId,
    int streakCount,
    DateTime? lastWorkoutDate,
  );
}
