import '../money/money.dart';
import 'allocation_plan.dart';

/// Split [sourceBalance] across [rules] in priority (sortOrder) order. Each
/// rule takes its fixed amount, capped by what is still available; a rule that
/// cannot be fully funded records a [PlanShortfall] and later rules see the
/// smaller remainder. A zero/negative balance funds nothing. Rules funded at
/// zero produce no [PlannedTransfer] (a transfer of 0 is meaningless) but are
/// still reported as shortfalls.
PlanApplyResult computePlanTransfers({
  required Money sourceBalance,
  required List<AllocationRule> rules,
}) {
  final currency = sourceBalance.currency;
  var remaining = sourceBalance.minorUnits;
  final transfers = <PlannedTransfer>[];
  final shortfalls = <PlanShortfall>[];
  var moved = 0;

  for (final rule in rules) {
    final requested = rule.amount.minorUnits;
    final available = remaining < 0 ? 0 : remaining;
    final funded = requested > available ? available : requested;

    if (funded < requested) {
      shortfalls.add(PlanShortfall(
        destinationAccountId: rule.destinationAccountId,
        requested: Money(requested, currency),
        funded: Money(funded < 0 ? 0 : funded, currency),
      ));
    }
    if (funded > 0) {
      transfers.add(PlannedTransfer(rule.destinationAccountId, Money(funded, currency)));
      remaining -= funded;
      moved += funded;
    }
  }

  return PlanApplyResult(
    transfers: transfers,
    totalMoved: Money(moved, currency),
    sourceRemaining: Money(remaining, currency),
    shortfalls: shortfalls,
  );
}
