// test/core/limit/safe_limit_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/time/financial_period.dart';
import 'package:financial_assistant/core/limit/safe_limit_engine.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => Money(v, uzs);
  // Jul 1 .. Aug 1; asOf Jul 18 => 14 days remaining (Jul18..Jul31 incl. today).
  final period = FinancialPeriod.containing(DateTime(2026, 7, 18), 1);

  SafeLimitInputs inputs({
    int variableBudget = 1400000,
    int variableSpent = 0,
    int manualBuffer = 0,
    int totalAvailable = 100000000,
    int minReserve = 0,
    int goalReserves = 0,
    int unpaidMandatory = 0,
    int todaySpent = 0,
    DateTime? asOf,
  }) =>
      SafeLimitInputs(
        variableBudget: m(variableBudget),
        variableSpent: m(variableSpent),
        manualBuffer: m(manualBuffer),
        totalAvailable: m(totalAvailable),
        minReserve: m(minReserve),
        goalReserves: m(goalReserves),
        unpaidMandatory: m(unpaidMandatory),
        todaySpent: m(todaySpent),
        period: period,
        asOf: asOf ?? DateTime(2026, 7, 18),
      );

  test('daily = remaining variable budget / days left', () {
    final r = dailySafeLimit(inputs()); // 1,400,000 / 14
    expect(r.daysLeft, 14);
    expect(r.spendable, m(1400000));
    expect(r.perDay, m(100000));
    expect(r.todayRemaining, m(100000));
    expect(r.isOver, isFalse);
  });

  test('variable spent and manual buffer reduce the numerator', () {
    final r = dailySafeLimit(inputs(variableSpent: 400000, manualBuffer: 100000));
    // (1,400,000 - 400,000 - 100,000) = 900,000 / 14 = 64285 (floored)
    expect(r.spendable, m(900000));
    expect(r.perDay, m(64285));
  });

  test('free-balance cap binds when reserved money exceeds the budget', () {
    // budget says 1,400,000 but only 500,000 is free after min reserve.
    final r = dailySafeLimit(inputs(totalAvailable: 900000, minReserve: 400000));
    expect(r.spendable, m(500000));
    expect(r.perDay, m(500000 ~/ 14));
  });

  test('goalReserves and unpaidMandatory also reduce free balance (0 in SP2, real later)', () {
    final r = dailySafeLimit(inputs(
        totalAvailable: 1000000, goalReserves: 300000, unpaidMandatory: 200000));
    expect(r.spendable, m(500000)); // 1,000,000 - 300,000 - 200,000
  });

  test('never negative: over-budget yields zero spendable and negative today remaining', () {
    final r = dailySafeLimit(inputs(variableBudget: 100000, variableSpent: 300000, todaySpent: 5000));
    expect(r.spendable, m(0));
    expect(r.perDay, m(0));
    expect(r.todayRemaining, m(-5000));
    expect(r.isOver, isTrue);
  });

  test('last day of the period floors days-left at 1 (no divide by zero)', () {
    final r = dailySafeLimit(inputs(asOf: DateTime(2026, 7, 31)));
    expect(r.daysLeft, 1);
    expect(r.perDay, m(1400000));
  });

  test('today remaining subtracts what was already spent today', () {
    final r = dailySafeLimit(inputs(todaySpent: 30000));
    expect(r.perDay, m(100000));
    expect(r.todayRemaining, m(70000));
  });

  test('weekly limit derives from the daily figure', () {
    final daily = dailySafeLimit(inputs()); // perDay 100,000
    final w = weeklySafeLimit(daily, daysLeftInWeek: 3, weeklySpent: m(250000));
    expect(w.weeklyRemaining, m(300000)); // 100,000 * 3
    expect(w.weeklySpent, m(250000));
    expect(w.weeklyLimit, m(550000)); // spent + remaining
  });
}
