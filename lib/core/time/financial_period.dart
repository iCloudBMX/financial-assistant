class FinancialPeriod {
  final DateTime start;
  final DateTime endExclusive;
  final int startDay; // the configured anchor day-of-month (1..31)

  const FinancialPeriod(this.start, this.endExclusive, this.startDay);

  static DateTime _clampedDate(int year, int month, int startDay) {
    // Normalize month overflow/underflow.
    final base = DateTime(year, month, 1);
    final lastDay = DateTime(base.year, base.month + 1, 0).day;
    final day = startDay > lastDay ? lastDay : startDay;
    return DateTime(base.year, base.month, day);
  }

  static FinancialPeriod containing(DateTime date, int startDay) {
    final thisMonthStart = _clampedDate(date.year, date.month, startDay);
    final DateTime start;
    if (!date.isBefore(thisMonthStart)) {
      start = thisMonthStart;
    } else {
      start = _clampedDate(date.year, date.month - 1, startDay);
    }
    final end = _clampedDate(start.year, start.month + 1, startDay);
    return FinancialPeriod(start, end, startDay);
  }

  bool contains(DateTime d) =>
      !d.isBefore(start) && d.isBefore(endExclusive);

  int get totalDays => endExclusive.difference(start).inDays;

  int daysRemaining(DateTime asOf) {
    final elapsed = asOf.difference(start).inDays;
    final remaining = totalDays - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  FinancialPeriod next() {
    final nextEnd =
        _clampedDate(endExclusive.year, endExclusive.month + 1, startDay);
    return FinancialPeriod(endExclusive, nextEnd, startDay);
  }

  FinancialPeriod previous() {
    final prevStart = _clampedDate(start.year, start.month - 1, startDay);
    return FinancialPeriod(prevStart, start, startDay);
  }

  @override
  bool operator ==(Object other) =>
      other is FinancialPeriod &&
      other.start == start &&
      other.endExclusive == endExclusive &&
      other.startDay == startDay;

  @override
  int get hashCode => Object.hash(start, endExclusive, startDay);
}
