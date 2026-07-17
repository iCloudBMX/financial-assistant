class FinancialPeriod {
  final DateTime start;
  final DateTime endExclusive;

  const FinancialPeriod(this.start, this.endExclusive);

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
    return FinancialPeriod(start, end);
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
    final nextEnd = _clampedDate(
        endExclusive.year, endExclusive.month + 1, endExclusive.day);
    return FinancialPeriod(endExclusive, nextEnd);
  }

  FinancialPeriod previous() {
    final prevStart =
        _clampedDate(start.year, start.month - 1, start.day);
    return FinancialPeriod(prevStart, start);
  }

  @override
  bool operator ==(Object other) =>
      other is FinancialPeriod &&
      other.start == start &&
      other.endExclusive == endExclusive;

  @override
  int get hashCode => Object.hash(start, endExclusive);
}
