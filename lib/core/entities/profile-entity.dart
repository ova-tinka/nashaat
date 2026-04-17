import 'enums.dart';

class ProfileEntity {
  final String id;
  final String email;
  final String? username;
  final String? firstName;
  final String? lastName;
  final UserStatus status;
  final int weeklyExerciseTargetMinutes;
  final int screenTimeBalanceMinutes;
  final int streakCount;
  final DateTime? lastWorkoutDate;
  final SubscriptionTier subscriptionTier;
  final String? fcmToken;
  final String? avatarMediaId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Screen-time economy setup
  final int dailyPhoneHours;
  final int weeklySmallSessions;
  final int weeklyBigSessions;
  final DateTime? lastWeeklyResetAt;

  const ProfileEntity({
    required this.id,
    required this.email,
    this.username,
    this.firstName,
    this.lastName,
    this.status = UserStatus.active,
    this.weeklyExerciseTargetMinutes = 0,
    this.screenTimeBalanceMinutes = 0,
    this.streakCount = 0,
    this.lastWorkoutDate,
    this.subscriptionTier = SubscriptionTier.free,
    this.fcmToken,
    this.avatarMediaId,
    required this.createdAt,
    required this.updatedAt,
    this.dailyPhoneHours = 0,
    this.weeklySmallSessions = 0,
    this.weeklyBigSessions = 0,
    this.lastWeeklyResetAt,
  });

  bool get isScreenTimeConfigured =>
      dailyPhoneHours > 0 &&
      (weeklySmallSessions + weeklyBigSessions) > 0;

  ProfileEntity copyWith({
    String? username,
    String? firstName,
    String? lastName,
    UserStatus? status,
    int? weeklyExerciseTargetMinutes,
    int? screenTimeBalanceMinutes,
    int? streakCount,
    DateTime? lastWorkoutDate,
    SubscriptionTier? subscriptionTier,
    String? fcmToken,
    String? avatarMediaId,
    DateTime? updatedAt,
    int? dailyPhoneHours,
    int? weeklySmallSessions,
    int? weeklyBigSessions,
    DateTime? lastWeeklyResetAt,
  }) {
    return ProfileEntity(
      id: id,
      email: email,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      status: status ?? this.status,
      weeklyExerciseTargetMinutes:
          weeklyExerciseTargetMinutes ?? this.weeklyExerciseTargetMinutes,
      screenTimeBalanceMinutes:
          screenTimeBalanceMinutes ?? this.screenTimeBalanceMinutes,
      streakCount: streakCount ?? this.streakCount,
      lastWorkoutDate: lastWorkoutDate ?? this.lastWorkoutDate,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      fcmToken: fcmToken ?? this.fcmToken,
      avatarMediaId: avatarMediaId ?? this.avatarMediaId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dailyPhoneHours: dailyPhoneHours ?? this.dailyPhoneHours,
      weeklySmallSessions: weeklySmallSessions ?? this.weeklySmallSessions,
      weeklyBigSessions: weeklyBigSessions ?? this.weeklyBigSessions,
      lastWeeklyResetAt: lastWeeklyResetAt ?? this.lastWeeklyResetAt,
    );
  }
}
