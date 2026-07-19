import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/allocation/allocation_models.dart';
import 'package:financial_assistant/core/allocation/allocation_engine.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => Money(v, uzs);

  AllocationDirection fixed(String k, int v) =>
      AllocationDirection(bucketKey: k, method: AllocationMethod.fixedAmount, amount: m(v));
  AllocationDirection pct(String k, int bp) =>
      AllocationDirection(bucketKey: k, method: AllocationMethod.percentage, percentBp: bp);
  AllocationDirection rest(String k) =>
      AllocationDirection(bucketKey: k, method: AllocationMethod.remaining);

  test('fixed + percentage-of-original + remaining split an income exactly', () {
    final r = computeAllocation(m(1000000), AllocationTemplate([
      fixed('mandatoryExpenses', 400000),
      pct('minReserve', 1000), // 10% of the ORIGINAL 1,000,000 = 100,000
      rest('variableBudget'),
    ]));
    expect(r.perBucket['mandatoryExpenses'], m(400000));
    expect(r.perBucket['minReserve'], m(100000));
    expect(r.perBucket['variableBudget'], m(500000));
    expect(r.totalAllocated, m(1000000));
    expect(r.undistributed, m(0));
    expect(r.shortfalls, isEmpty);
  });

  test('with no remaining direction the leftover is undistributed', () {
    final r = computeAllocation(m(1000000), AllocationTemplate([
      fixed('mandatoryExpenses', 300000),
    ]));
    expect(r.totalAllocated, m(300000));
    expect(r.undistributed, m(700000));
  });

  test('percentage floors (no fractional minor units)', () {
    final r = computeAllocation(m(1005), AllocationTemplate([pct('minReserve', 3333)]));
    // 1005 * 3333 / 10000 = 334.9665 -> 334
    expect(r.perBucket['minReserve'], m(334));
  });

  test('§8.5 insufficient income: later fixed direction is partially funded, shortfall recorded', () {
    final r = computeAllocation(m(500000), AllocationTemplate([
      fixed('mandatoryExpenses', 400000),
      fixed('minReserve', 300000), // only 100000 left
    ]));
    expect(r.perBucket['mandatoryExpenses'], m(400000));
    expect(r.perBucket['minReserve'], m(100000));
    expect(r.totalAllocated, m(500000));
    expect(r.undistributed, m(0));
    expect(r.shortfalls.single.bucketKey, 'minReserve');
    expect(r.shortfalls.single.requested, m(300000));
    expect(r.shortfalls.single.funded, m(100000));
    expect(r.shortfalls.single.shortBy, m(200000));
  });

  test('a fully starved direction funds zero and records the shortfall', () {
    final r = computeAllocation(m(400000), AllocationTemplate([
      fixed('mandatoryExpenses', 400000),
      fixed('minReserve', 50000),
    ]));
    expect(r.perBucket.containsKey('minReserve'), isFalse);
    expect(r.shortfalls.single.bucketKey, 'minReserve');
    expect(r.shortfalls.single.funded, m(0));
  });
}
