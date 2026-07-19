import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/allocation/allocation_models.dart';
import 'package:financial_assistant/core/allocation/allocation_dynamic.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => Money(v, uzs);

  test('goalBased direction becomes a fixedAmount from the resolved map', () {
    final t = const AllocationTemplate([
      AllocationDirection(bucketKey: 'minReserve', method: AllocationMethod.percentage, percentBp: 1000),
      AllocationDirection(bucketKey: 'goal:7', method: AllocationMethod.goalBased),
      AllocationDirection(bucketKey: 'variableBudget', method: AllocationMethod.remaining),
    ]);
    final resolved = resolveDynamicAmounts(t, {'goal:7': m(300)});
    final g = resolved.directions[1];
    expect(g.method, AllocationMethod.fixedAmount);
    expect(g.amount, m(300));
    expect(g.bucketKey, 'goal:7');
    // others unchanged
    expect(resolved.directions[0].method, AllocationMethod.percentage);
    expect(resolved.directions[2].method, AllocationMethod.remaining);
  });

  test('unresolved goalBased direction becomes a zero fixedAmount', () {
    final t = const AllocationTemplate([
      AllocationDirection(bucketKey: 'goal:9', method: AllocationMethod.goalBased),
    ]);
    final resolved = resolveDynamicAmounts(t, {});
    expect(resolved.directions.single.method, AllocationMethod.fixedAmount);
    expect(resolved.directions.single.amount, m(0));
  });
}
