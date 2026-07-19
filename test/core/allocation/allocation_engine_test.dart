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

  group('previewAllocation (§8.4 preview: income/directions/allocatedTotal/'
      'unallocated/freeAfter/shortfall)', () {
    test('a balanced split leaves unallocated and freeAfter at zero', () {
      final template = AllocationTemplate([
        pct('minReserve', 1000), // 10%
        rest('variableBudget'),
      ]);
      final p = previewAllocation(m(1000000), template);
      expect(p.income, m(1000000));
      expect(p.directions, template.directions);
      expect(p.perBucket['minReserve'], m(100000));
      expect(p.perBucket['variableBudget'], m(900000));
      expect(p.allocatedTotal, m(1000000));
      expect(p.unallocated, m(0));
      expect(p.freeAfter, m(0));
      expect(p.shortfall, isEmpty);
    });

    test('with no remaining direction, unallocated and freeAfter equal the '
        'leftover', () {
      final p = previewAllocation(
          m(1000000), AllocationTemplate([fixed('mandatoryExpenses', 300000)]));
      expect(p.allocatedTotal, m(300000));
      expect(p.unallocated, m(700000));
      expect(p.freeAfter, m(700000));
    });

    test(
        'insufficient income: priority reduction — the first (highest-'
        'priority) direction is funded in full, a later direction is '
        'reduced, and the exact shortfall is exposed', () {
      final p = previewAllocation(
        m(500000),
        AllocationTemplate([
          fixed('mandatoryExpenses', 400000), // critical, first in order
          fixed('minReserve', 300000), // lower priority, only 100000 left
        ]),
      );
      expect(p.perBucket['mandatoryExpenses'], m(400000),
          reason: 'the first/critical direction is never reduced while '
              'funds remain');
      expect(p.perBucket['minReserve'], m(100000),
          reason: 'the later direction absorbs the shortage');
      expect(p.allocatedTotal, m(500000));
      expect(p.unallocated, m(0));
      expect(p.shortfall.single.bucketKey, 'minReserve');
      expect(p.shortfall.single.shortBy, m(200000));
      // Never over-allocated by construction — confirm must stay enabled.
      expect(p.allocatedTotal.minorUnits <= p.income.minorUnits, isTrue);
    });
  });

  group('editedAllocationPreview (user-edited amounts, e.g. AllocateSheet)',
      () {
    final directions = [
      const AllocationDirection(
          bucketKey: 'minReserve', method: AllocationMethod.percentage,
          percentBp: 1000),
      const AllocationDirection(
          bucketKey: 'variableBudget', method: AllocationMethod.remaining),
    ];

    test('edited amounts under income leave a positive unallocated/freeAfter',
        () {
      final p = editedAllocationPreview(m(1000000), directions, {
        'minReserve': m(100000),
      });
      expect(p.allocatedTotal, m(100000));
      expect(p.unallocated, m(900000));
      expect(p.freeAfter, m(900000));
      expect(p.shortfall, isEmpty,
          reason: 'user-edited totals do not compute a shortfall');
    });

    test('edited amounts exceeding income make unallocated negative but '
        'freeAfter stays clamped at zero — the signal that disables '
        'confirm', () {
      final p = editedAllocationPreview(m(1000000), directions, {
        'minReserve': m(700000),
        'variableBudget': m(500000),
      });
      expect(p.allocatedTotal, m(1200000));
      expect(p.unallocated, m(-200000));
      expect(p.freeAfter, m(0));
      expect(p.allocatedTotal.minorUnits <= p.income.minorUnits, isFalse);
    });

    test('a zero or missing entry contributes nothing', () {
      final p = editedAllocationPreview(m(1000000), directions, {
        'minReserve': m(0),
      });
      expect(p.perBucket, isEmpty);
      expect(p.allocatedTotal, m(0));
    });
  });
}
