import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/time/financial_period.dart';
import 'package:financial_assistant/core/time/weekday.dart';

void main() {
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  test('period starting on the 5th contains a mid-month date', () {
    final p = FinancialPeriod.containing(d(2026, 3, 10), 5);
    expect(p.start, d(2026, 3, 5));
    expect(p.endExclusive, d(2026, 4, 5));
    expect(p.contains(d(2026, 3, 10)), isTrue);
  });

  test('a date before the start day belongs to the previous period', () {
    final p = FinancialPeriod.containing(d(2026, 3, 2), 5);
    expect(p.start, d(2026, 2, 5));
    expect(p.endExclusive, d(2026, 3, 5));
  });

  test('start day 31 clamps to the last day of a short month', () {
    final p = FinancialPeriod.containing(d(2026, 2, 15), 31);
    expect(p.start, d(2026, 1, 31));
    expect(p.endExclusive, d(2026, 2, 28));
  });

  test('totalDays and daysRemaining', () {
    final p = FinancialPeriod.containing(d(2026, 3, 10), 1);
    expect(p.totalDays, 31);
    expect(p.daysRemaining(d(2026, 3, 10)), 22); // 31 - 9 days elapsed
  });

  test('next and previous are contiguous', () {
    final p = FinancialPeriod.containing(d(2026, 3, 10), 5);
    expect(p.next().start, p.endExclusive);
    expect(p.previous().endExclusive, p.start);
  });

  test('startOfWeek snaps to Monday when weekStart=1', () {
    // 2026-07-15 is a Wednesday.
    expect(startOfWeek(DateTime(2026, 7, 15), 1), DateTime(2026, 7, 13));
  });

  test('next() preserves the configured anchor across a clamped month', () {
    var p = FinancialPeriod.containing(DateTime(2026, 1, 31), 31);
    expect(p.start, DateTime(2026, 1, 31));
    expect(p.endExclusive, DateTime(2026, 2, 28)); // Feb clamps
    p = p.next();
    expect(p.start, DateTime(2026, 2, 28));
    expect(p.endExclusive, DateTime(2026, 3, 31)); // recovers to 31
    p = p.next();
    expect(p.start, DateTime(2026, 3, 31));
    expect(p.endExclusive, DateTime(2026, 4, 30)); // Apr clamps to 30
    p = p.next();
    expect(p.start, DateTime(2026, 4, 30));
    expect(p.endExclusive, DateTime(2026, 5, 31)); // recovers to 31
  });

  test('previous() preserves the configured anchor across a clamped month', () {
    // March-anchored period for startDay 31 spans Feb 28 -> Mar 31.
    var p = FinancialPeriod.containing(DateTime(2026, 3, 15), 31);
    expect(p.start, DateTime(2026, 2, 28));
    expect(p.endExclusive, DateTime(2026, 3, 31));
    p = p.previous();
    expect(p.start, DateTime(2026, 1, 31)); // recovers to 31, not 28
    expect(p.endExclusive, DateTime(2026, 2, 28));
  });
}
