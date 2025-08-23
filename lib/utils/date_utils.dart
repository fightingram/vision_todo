import '../providers/settings_provider.dart';

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime startOfWeek(DateTime d, WeekStart start) {
  final weekday = d.weekday; // 1=Mon..7=Sun
  final diff = start == WeekStart.monday ? weekday - 1 : (weekday % 7);
  return DateTime(d.year, d.month, d.day).subtract(Duration(days: diff));
}

DateTime endOfWeek(DateTime d, WeekStart start) {
  final s = startOfWeek(d, start);
  return DateTime(s.year, s.month, s.day, 23, 59, 59, 999).add(const Duration(days: 6));
}

