abstract final class WeekHelper {
  /// Returns the Monday (start) of the ISO week containing [date].
  static DateTime weekStart(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    // weekday: 1=Mon … 7=Sun
    return d.subtract(Duration(days: d.weekday - 1));
  }

  /// Returns the Sunday (end, inclusive) of the ISO week containing [date].
  static DateTime weekEnd(DateTime date) {
    return weekStart(date).add(const Duration(days: 6));
  }

  /// Returns true if [date] falls within the current ISO week.
  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    final start = weekStart(now);
    final end = weekEnd(now).add(const Duration(days: 1)); // exclusive upper bound
    return !date.isBefore(start) && date.isBefore(end);
  }

  /// Returns a list of 7 DateTimes representing Mon-Sun for the current week.
  static List<DateTime> currentWeekDays() {
    final start = weekStart(DateTime.now());
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  /// Converts a weekday int (1=Mon, 7=Sun) to a short label.
  static String shortDayLabel(int weekday) => const [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ][weekday - 1];

  /// Produces a concise summary of scheduled days.
  static String formatScheduledDays(List<int> days) {
    if (days.isEmpty) return 'No days set';
    final sorted = [...days]..sort();
    if (sorted.length == 7) return 'Every day';
    if (sorted.length == 5 &&
        sorted.every((d) => d >= 1 && d <= 5)) return 'Weekdays';
    if (sorted.length == 2 && sorted.contains(6) && sorted.contains(7)) {
      return 'Weekends';
    }
    return sorted.map(shortDayLabel).join(', ');
  }

  /// Maps a workday integer to a full name.
  static String fullDayName(int weekday) => const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ][weekday - 1];
}
