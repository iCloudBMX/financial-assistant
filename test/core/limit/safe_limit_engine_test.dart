// test/core/limit/safe_limit_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/limit/safe_limit_engine.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => Money(v, uzs);

  test('daily = spendable pool / days left (integer floor)', () {
    final r = dailySpendLimit(
        spendablePool: m(1400000), daysLeft: 14, todaySpent: m(0));
    expect(r.daysLeft, 14);
    expect(r.spendable, m(1400000));
    expect(r.perDay, m(100000)); // 1,400,000 / 14
    expect(r.todayRemaining, m(100000));
    expect(r.isOver, isFalse);
  });

  test('floors the per-day figure', () {
    final r = dailySpendLimit(
        spendablePool: m(900000), daysLeft: 14, todaySpent: m(0));
    expect(r.perDay, m(64285)); // 900,000 / 14 = 64285.7 -> 64285
  });

  test('empty pool yields zero limit (zero Sarf accounts)', () {
    final r =
        dailySpendLimit(spendablePool: m(0), daysLeft: 14, todaySpent: m(0));
    expect(r.spendable, m(0));
    expect(r.perDay, m(0));
    expect(r.todayRemaining, m(0));
  });

  test('negative pool is floored at zero, never negative spendable', () {
    final r = dailySpendLimit(
        spendablePool: m(-500000), daysLeft: 10, todaySpent: m(5000));
    expect(r.spendable, m(0));
    expect(r.perDay, m(0));
    expect(r.todayRemaining, m(-5000));
    expect(r.isOver, isTrue);
  });

  test('days-left floored at 1 (no divide by zero on the last day)', () {
    final r = dailySpendLimit(
        spendablePool: m(1400000), daysLeft: 0, todaySpent: m(0));
    expect(r.daysLeft, 1);
    expect(r.perDay, m(1400000));
  });

  test('today remaining subtracts what was already spent today', () {
    final r = dailySpendLimit(
        spendablePool: m(1400000), daysLeft: 14, todaySpent: m(30000));
    expect(r.perDay, m(100000));
    expect(r.todayRemaining, m(70000));
  });

  test('hasSpendingAccounts flag propagates from the caller', () {
    final withCard = dailySpendLimit(
        spendablePool: m(0),
        daysLeft: 14,
        todaySpent: m(0),
        hasSpendingAccounts: true);
    expect(withCard.hasSpendingAccounts, isTrue);
    expect(withCard.spendable, m(0)); // present-but-empty pool
    final none = dailySpendLimit(
        spendablePool: m(0),
        daysLeft: 14,
        todaySpent: m(0),
        hasSpendingAccounts: false);
    expect(none.hasSpendingAccounts, isFalse);
  });

  test('hasSpendingAccounts defaults to true when omitted', () {
    final r = dailySpendLimit(
        spendablePool: m(1400000), daysLeft: 14, todaySpent: m(0));
    expect(r.hasSpendingAccounts, isTrue);
  });

  test('weekly limit still derives from the daily figure', () {
    final daily = dailySpendLimit(
        spendablePool: m(1400000), daysLeft: 14, todaySpent: m(0));
    final w = weeklySafeLimit(daily, daysLeftInWeek: 3, weeklySpent: m(250000));
    expect(w.weeklyRemaining, m(300000)); // 100,000 * 3
    expect(w.weeklySpent, m(250000));
    expect(w.weeklyLimit, m(550000));
  });
}
