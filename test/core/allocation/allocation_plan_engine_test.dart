import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/allocation/allocation_plan.dart';
import 'package:financial_assistant/core/allocation/allocation_plan_engine.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => Money(v, uzs);

  AllocationRule rule(int dest, int amount, int order) =>
      AllocationRule(destinationAccountId: dest, amount: m(amount), sortOrder: order);

  test('funds every rule exactly when the balance covers them', () {
    final r = computePlanTransfers(sourceBalance: m(2000000), rules: [
      rule(2, 500000, 0),
      rule(3, 300000, 1),
    ]);
    expect(r.transfers.length, 2);
    expect(r.transfers[0].destinationAccountId, 2);
    expect(r.transfers[0].amount, m(500000));
    expect(r.transfers[1].amount, m(300000));
    expect(r.totalMoved, m(800000));
    expect(r.sourceRemaining, m(1200000));
    expect(r.shortfalls, isEmpty);
  });

  test('priority fill: partial last funded rule, later rules get zero', () {
    final r = computePlanTransfers(sourceBalance: m(700000), rules: [
      rule(2, 500000, 0),
      rule(3, 300000, 1),
      rule(4, 200000, 2),
    ]);
    // 500k full, 200k left -> rule 3 gets 200k (short 100k), rule 4 gets 0.
    expect(r.transfers.length, 2);
    expect(r.transfers[0].amount, m(500000));
    expect(r.transfers[1].destinationAccountId, 3);
    expect(r.transfers[1].amount, m(200000));
    expect(r.totalMoved, m(700000));
    expect(r.sourceRemaining, m(0));
    expect(r.shortfalls.length, 2);
    expect(r.shortfalls[0].destinationAccountId, 3);
    expect(r.shortfalls[0].shortBy, m(100000));
    expect(r.shortfalls[1].destinationAccountId, 4);
    expect(r.shortfalls[1].funded, m(0));
    expect(r.shortfalls[1].shortBy, m(200000));
  });

  test('empty rules produce no transfers and keep the full balance', () {
    final r = computePlanTransfers(sourceBalance: m(1000000), rules: const []);
    expect(r.transfers, isEmpty);
    expect(r.totalMoved, m(0));
    expect(r.sourceRemaining, m(1000000));
    expect(r.shortfalls, isEmpty);
  });

  test('zero balance funds nothing; all rules are shortfalls', () {
    final r = computePlanTransfers(sourceBalance: m(0), rules: [rule(2, 500000, 0)]);
    expect(r.transfers, isEmpty);
    expect(r.totalMoved, m(0));
    expect(r.sourceRemaining, m(0));
    expect(r.shortfalls.single.shortBy, m(500000));
  });

  test('negative balance funds nothing and stays negative', () {
    final r = computePlanTransfers(sourceBalance: m(-50000), rules: [rule(2, 100000, 0)]);
    expect(r.transfers, isEmpty);
    expect(r.sourceRemaining, m(-50000));
    expect(r.shortfalls.single.funded, m(0));
  });
}
