/// Returns midnight of the week-start day for [date].
/// [weekStartIso]: 1=Monday … 7=Sunday (matches DateTime.weekday).
DateTime startOfWeek(DateTime date, int weekStartIso) {
  final day = DateTime(date.year, date.month, date.day);
  final diff = (day.weekday - weekStartIso + 7) % 7;
  return day.subtract(Duration(days: diff));
}
