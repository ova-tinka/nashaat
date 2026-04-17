import '../../core/entities/enums.dart';
import '../../core/entities/profile-entity.dart';

class ScreenTimeRewards {
  final int smallRewardMinutes;
  final int bigRewardMinutes;
  final int freeMinutes;
  final int weeklyPhoneMinutes;

  const ScreenTimeRewards({
    required this.smallRewardMinutes,
    required this.bigRewardMinutes,
    required this.freeMinutes,
    required this.weeklyPhoneMinutes,
  });

  static const zero = ScreenTimeRewards(
    smallRewardMinutes: 0,
    bigRewardMinutes: 0,
    freeMinutes: 0,
    weeklyPhoneMinutes: 0,
  );

  int rewardFor(SessionSize size) =>
      size == SessionSize.big ? bigRewardMinutes : smallRewardMinutes;
}

class ScreenTimeEconomy {
  static const double _freePercent = 0.20;

  /// Calculates the weekly reward breakdown from a user's profile settings.
  ///
  /// Example — 8 h/day, 2 small + 3 big sessions:
  ///   weeklyPhoneMinutes = 8 × 7 × 60 = 3360 (56 h)
  ///   freeMinutes        = floor(3360 × 0.20) = 672 (≈11 h, always available)
  ///   earnableMinutes    = 3360 − 672 = 2688 (≈45 h, earned through workouts)
  ///   totalUnits         = 2×1 + 3×2 = 8
  ///   smallReward        = floor(2688 / 8) = 336 min (5.6 h)
  ///   bigReward          = 336 × 2 = 672 min (11.2 h)
  static ScreenTimeRewards calculate(ProfileEntity profile) {
    final totalSessions = profile.weeklySmallSessions + profile.weeklyBigSessions;
    if (profile.dailyPhoneHours <= 0 || totalSessions == 0) {
      return ScreenTimeRewards.zero;
    }

    final weeklyPhoneMinutes = profile.dailyPhoneHours * 7 * 60;
    final freeMinutes = (weeklyPhoneMinutes * _freePercent).floor();
    final earnableMinutes = weeklyPhoneMinutes - freeMinutes;
    final totalUnits =
        profile.weeklySmallSessions * 1 + profile.weeklyBigSessions * 2;
    final smallRewardMinutes = (earnableMinutes / totalUnits).floor();

    return ScreenTimeRewards(
      smallRewardMinutes: smallRewardMinutes,
      bigRewardMinutes: smallRewardMinutes * 2,
      freeMinutes: freeMinutes,
      weeklyPhoneMinutes: weeklyPhoneMinutes,
    );
  }

  static int rewardMinutes(ProfileEntity profile, SessionSize size) =>
      calculate(profile).rewardFor(size);

  /// Convenience overload for UI previews that don't have a full ProfileEntity.
  static ScreenTimeRewards calculateRaw({
    required int dailyPhoneHours,
    required int weeklySmallSessions,
    required int weeklyBigSessions,
  }) {
    final totalSessions = weeklySmallSessions + weeklyBigSessions;
    if (dailyPhoneHours <= 0 || totalSessions == 0) {
      return ScreenTimeRewards.zero;
    }
    final weeklyPhoneMinutes = dailyPhoneHours * 7 * 60;
    final freeMinutes = (weeklyPhoneMinutes * _freePercent).floor();
    final earnableMinutes = weeklyPhoneMinutes - freeMinutes;
    final totalUnits = weeklySmallSessions * 1 + weeklyBigSessions * 2;
    final smallRewardMinutes = (earnableMinutes / totalUnits).floor();
    return ScreenTimeRewards(
      smallRewardMinutes: smallRewardMinutes,
      bigRewardMinutes: smallRewardMinutes * 2,
      freeMinutes: freeMinutes,
      weeklyPhoneMinutes: weeklyPhoneMinutes,
    );
  }

  /// Returns true if [now] falls in a different ISO week than [lastReset].
  static bool isNewWeek(DateTime now, DateTime? lastReset) {
    if (lastReset == null) return true;
    final currentMonday = _mondayOf(now);
    final lastMonday = _mondayOf(lastReset);
    return currentMonday.isAfter(lastMonday);
  }

  static DateTime _mondayOf(DateTime d) {
    final daysFromMonday = (d.weekday - 1) % 7;
    final monday = d.subtract(Duration(days: daysFromMonday));
    return DateTime(monday.year, monday.month, monday.day);
  }
}
