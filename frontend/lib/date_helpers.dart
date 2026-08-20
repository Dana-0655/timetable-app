/// Shared helpers so every timetable-related screen computes and
/// displays "today's real date for this weekday" the exact same way.
class DateHelpers {
  static const List<String> weekDayCodes = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  static const List<String> _monthAbbr = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// The real calendar date for the given day code, offset by weeks.
  /// weekOffset = 0 means current week, 1 means next week, -1 means previous week.
  static DateTime dateForDayCode(String dayCode, {int weekOffset = 0}) {
    final now = DateTime.now();
    final todayIndex = now.weekday - 1; // Dart: Mon=1..Sun=7 -> 0..6
    final targetIndex = weekDayCodes.indexOf(dayCode);
    if (targetIndex == -1) return now;
    final diff = (targetIndex - todayIndex) + (weekOffset * 7);
    final today = DateTime(now.year, now.month, now.day);
    return today.add(Duration(days: diff));
  }

  /// Short label like "15 Aug"
  static String shortLabel(DateTime date) {
    return '${date.day} ${_monthAbbr[date.month - 1]}';
  }

  /// Whether the given day code's date is today.
  static bool isToday(String dayCode, {int weekOffset = 0}) {
    final now = DateTime.now();
    final target = dateForDayCode(dayCode, weekOffset: weekOffset);
    return now.year == target.year &&
        now.month == target.month &&
        now.day == target.day;
  }

  /// Convenience: "15 Aug" for a day code directly.
  static String labelForDayCode(String dayCode, {int weekOffset = 0}) {
    return shortLabel(dateForDayCode(dayCode, weekOffset: weekOffset));
  }

  /// "YYYY-MM-DD" for a given date - matches the format holidays are
  /// stored/checked against on the backend.
  static String isoDate(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  /// "YYYY-MM-DD" for a given day code and weekOffset.
  static String isoForDayCode(String dayCode, {int weekOffset = 0}) {
    return isoDate(dateForDayCode(dayCode, weekOffset: weekOffset));
  }

  /// Range string e.g. "17 Aug - 23 Aug" for a given weekOffset
  static String weekRangeLabel({int weekOffset = 0}) {
    final mon = dateForDayCode('MON', weekOffset: weekOffset);
    final sun = dateForDayCode('SUN', weekOffset: weekOffset);
    return '${shortLabel(mon)} - ${shortLabel(sun)}';
  }
}
