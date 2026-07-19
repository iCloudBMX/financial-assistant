import '../money/currency.dart';
import '../money/money.dart';
import 'allocation_models.dart';

/// Resolve dynamic directions (`goalBased`) to concrete `fixedAmount`s before
/// [computeAllocation] runs, so the pure allocation engine never needs goal
/// data. A `goalBased` direction takes its amount from [resolvedFixed] keyed by
/// `bucketKey` (e.g. `goal:7`); an unresolved one becomes a zero fixedAmount.
/// Order and every non-goalBased direction are preserved unchanged.
AllocationTemplate resolveDynamicAmounts(
  AllocationTemplate template,
  Map<String, Money> resolvedFixed,
) {
  final out = template.directions.map((d) {
    if (d.method != AllocationMethod.goalBased) return d;
    final amount = resolvedFixed[d.bucketKey];
    return AllocationDirection(
      bucketKey: d.bucketKey,
      method: AllocationMethod.fixedAmount,
      amount: amount ?? Money.zero(_currencyOf(resolvedFixed)),
    );
  }).toList();
  return AllocationTemplate(out);
}

// A zero fixedAmount needs a currency; use any resolved value's currency, or
// fall back to UZS when the map is empty (an unresolved goal contributes 0
// regardless of currency because computeAllocation caps it at what's left).
Currency _currencyOf(Map<String, Money> resolved) =>
    resolved.isEmpty ? CurrencyRegistry.uzs : resolved.values.first.currency;
