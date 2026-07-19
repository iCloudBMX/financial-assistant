// test/core/goal/goal_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/goal/goal_engine.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => Money(v, uzs);

  GoalProgress progress({
    required int saved,
    required int target,
    required DateTime start,
    DateTime? targetDate,
    required DateTime asOf,
  }) =>
      computeGoalProgress(GoalProgressInputs(
        saved: m(saved),
        target: m(target),
        startDate: start,
        targetDate: targetDate,
        asOf: asOf,
      ));

  test('remaining and percent are derived from saved vs target', () {
    final p = progress(
      saved: 250,
      target: 1000,
      start: DateTime(2026, 1, 1),
      asOf: DateTime(2026, 2, 1),
    );
    expect(p.remaining, m(750));
    expect(p.percentBp, 2500); // 25.00%
  });

  test('percent clamps to 100% when saved exceeds target', () {
    final p = progress(
      saved: 1500,
      target: 1000,
      start: DateTime(2026, 1, 1),
      asOf: DateTime(2026, 2, 1),
    );
    expect(p.remaining, m(0)); // never negative
    expect(p.percentBp, 10000);
  });

  test('target of zero yields 100% (guarded, no divide-by-zero)', () {
    final p = progress(
      saved: 0,
      target: 0,
      start: DateTime(2026, 1, 1),
      asOf: DateTime(2026, 2, 1),
    );
    expect(p.percentBp, 10000);
  });

  test('projectedDate is null when nothing saved yet (no rate)', () {
    final p = progress(
      saved: 0,
      target: 1000,
      start: DateTime(2026, 1, 1),
      asOf: DateTime(2026, 2, 1),
    );
    expect(p.projectedDate, isNull);
  });

  test('projectedDate extrapolates from average rate since start', () {
    // 100 saved over 10 elapsed days => 10/day; 900 remaining => 90 more days.
    final p = progress(
      saved: 100,
      target: 1000,
      start: DateTime(2026, 1, 1),
      asOf: DateTime(2026, 1, 11), // 10 days elapsed
    );
    expect(p.projectedDate, DateTime(2026, 1, 11).add(const Duration(days: 90)));
  });

  test('requiredMonthly is null without a deadline', () {
    final p = progress(
      saved: 100,
      target: 1000,
      start: DateTime(2026, 1, 1),
      asOf: DateTime(2026, 1, 11),
    );
    expect(p.requiredMonthly, isNull);
  });

  test('requiredMonthly ceil-divides remaining over months left', () {
    // remaining 900, from 2026-01-11 to 2026-04-11 => 3 months => 300/mo.
    final p = progress(
      saved: 100,
      target: 1000,
      start: DateTime(2026, 1, 1),
      targetDate: DateTime(2026, 4, 11),
      asOf: DateTime(2026, 1, 11),
    );
    expect(p.requiredMonthly, m(300));
  });

  test('requiredMonthly uses at least one month for a past deadline', () {
    final p = progress(
      saved: 100,
      target: 1000,
      start: DateTime(2026, 1, 1),
      targetDate: DateTime(2025, 12, 1), // already past
      asOf: DateTime(2026, 1, 11),
    );
    expect(p.requiredMonthly, m(900)); // fund the whole remainder now
  });

  test('onTrack compares projected vs target date', () {
    final ahead = progress(
      saved: 500,
      target: 1000,
      start: DateTime(2026, 1, 1),
      targetDate: DateTime(2027, 1, 1),
      asOf: DateTime(2026, 1, 11),
    );
    expect(ahead.onTrack, isTrue);
    expect(ahead.daysToTargetDate, DateTime(2027, 1, 1).difference(DateTime(2026, 1, 11)).inDays);
  });
}
