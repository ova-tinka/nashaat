import '../../core/entities/enums.dart';
import '../../core/entities/profile-entity.dart';
import '../../core/repositories/profile-repository.dart';
import '../../shared/logger.dart';
import 'supabase-client.dart';

class SupabaseProfileRepository implements ProfileRepository {
  final _db = SupabaseClientProvider.client;

  @override
  Future<ProfileEntity?> getProfile(String userId) async {
    final data = await _db
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    Log.db('profile loaded for ${userId.substring(0, 8)}…');
    return _fromMap(data);
  }

  @override
  Future<ProfileEntity> updateProfile(
    String userId, {
    String? username,
    String? firstName,
    String? lastName,
    int? weeklyExerciseTargetMinutes,
    String? fcmToken,
    String? avatarMediaId,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (username != null) updates['username'] = username;
    if (firstName != null) updates['first_name'] = firstName;
    if (lastName != null) updates['last_name'] = lastName;
    if (weeklyExerciseTargetMinutes != null) {
      updates['weekly_exercise_target_minutes'] = weeklyExerciseTargetMinutes;
    }
    if (fcmToken != null) updates['fcm_token'] = fcmToken;
    if (avatarMediaId != null) updates['avatar_media_id'] = avatarMediaId;

    final data = await _db
        .from('profiles')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();
    Log.db('profile updated ✓');
    return _fromMap(data);
  }

  @override
  Future<void> updateStatus(String userId, UserStatus status) async {
    await _db.from('profiles').update({
      'status': _statusToString(status),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
    Log.db('profile status → ${_statusToString(status)}');
  }

  @override
  Future<void> updateScreenTimeBalance(String userId, int balanceMinutes) async {
    await _db.from('profiles').update({
      'screen_time_balance_minutes': balanceMinutes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  @override
  Future<void> updateStreak(
    String userId,
    int streakCount,
    DateTime? lastWorkoutDate,
  ) async {
    await _db.from('profiles').update({
      'streak_count': streakCount,
      'last_workout_date': lastWorkoutDate?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  @override
  Future<void> updateScreenTimeSetup(
    String userId, {
    required int dailyPhoneHours,
    required int weeklySmallSessions,
    required int weeklyBigSessions,
  }) async {
    await _db.from('profiles').update({
      'daily_phone_hours': dailyPhoneHours,
      'weekly_small_sessions': weeklySmallSessions,
      'weekly_big_sessions': weeklyBigSessions,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
    Log.db('screen-time setup updated ✓ '
        '${dailyPhoneHours}h/day, '
        '${weeklySmallSessions}S+${weeklyBigSessions}B');
  }

  @override
  Future<void> updateLastWeeklyReset(String userId, DateTime resetAt) async {
    await _db.from('profiles').update({
      'last_weekly_reset_at': resetAt.toIso8601String(),
      'screen_time_balance_minutes': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
    Log.db('weekly reset recorded ✓');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  ProfileEntity _fromMap(Map<String, dynamic> map) => ProfileEntity(
        id: map['id'] as String,
        email: map['email'] as String,
        username: map['username'] as String?,
        firstName: map['first_name'] as String?,
        lastName: map['last_name'] as String?,
        status: _parseStatus(map['status'] as String? ?? 'active'),
        weeklyExerciseTargetMinutes:
            map['weekly_exercise_target_minutes'] as int? ?? 0,
        screenTimeBalanceMinutes:
            map['screen_time_balance_minutes'] as int? ?? 0,
        streakCount: map['streak_count'] as int? ?? 0,
        lastWorkoutDate: map['last_workout_date'] != null
            ? DateTime.tryParse(map['last_workout_date'] as String)
            : null,
        subscriptionTier:
            _parseTier(map['subscription_tier'] as String? ?? 'free'),
        fcmToken: map['fcm_token'] as String?,
        avatarMediaId: map['avatar_media_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        dailyPhoneHours: map['daily_phone_hours'] as int? ?? 0,
        weeklySmallSessions: map['weekly_small_sessions'] as int? ?? 0,
        weeklyBigSessions: map['weekly_big_sessions'] as int? ?? 0,
        lastWeeklyResetAt: map['last_weekly_reset_at'] != null
            ? DateTime.tryParse(map['last_weekly_reset_at'] as String)
            : null,
      );

  UserStatus _parseStatus(String s) => switch (s) {
        'verified' => UserStatus.verified,
        'onboarded' => UserStatus.onboarded,
        'inactive' => UserStatus.inactive,
        'deleted' => UserStatus.deleted,
        'suspended' => UserStatus.suspended,
        _ => UserStatus.active,
      };

  String _statusToString(UserStatus s) => switch (s) {
        UserStatus.active => 'active',
        UserStatus.verified => 'verified',
        UserStatus.onboarded => 'onboarded',
        UserStatus.inactive => 'inactive',
        UserStatus.deleted => 'deleted',
        UserStatus.suspended => 'suspended',
      };

  SubscriptionTier _parseTier(String s) =>
      s == 'vip' ? SubscriptionTier.vip : SubscriptionTier.free;
}
