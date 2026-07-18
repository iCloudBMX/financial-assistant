import '../money/money.dart';
import 'allocation_models.dart';

/// Split [income] across [template] in order. `fixedAmount` takes its amount
/// (capped by what is left); `percentage` takes `percentBp` of the ORIGINAL
/// income (floored); `remaining` takes everything still unallocated. Any
/// direction that cannot be fully funded records a [Shortfall] and later
/// directions see a smaller remainder (§8.5). Whatever is left over is
/// `undistributed`.
AllocationResult computeAllocation(Money income, AllocationTemplate template) {
  final currency = income.currency;
  var remaining = income.minorUnits;
  var totalAllocated = 0;
  final perBucket = <String, Money>{};
  final shortfalls = <Shortfall>[];

  for (final d in template.directions) {
    var requested = switch (d.method) {
      AllocationMethod.fixedAmount => d.amount?.minorUnits ?? 0,
      AllocationMethod.percentage =>
        income.minorUnits * (d.percentBp ?? 0) ~/ 10000,
      AllocationMethod.remaining => remaining < 0 ? 0 : remaining,
    };
    if (requested < 0) requested = 0;

    final available = remaining < 0 ? 0 : remaining;
    final funded = requested > available ? available : requested;

    if (funded < requested) {
      shortfalls.add(Shortfall(
          d.bucketKey, Money(requested, currency), Money(funded, currency)));
    }
    if (funded > 0) {
      final existing = perBucket[d.bucketKey];
      final add = Money(funded, currency);
      perBucket[d.bucketKey] = existing == null ? add : existing.add(add);
      remaining -= funded;
      totalAllocated += funded;
    }
  }

  return AllocationResult(
    perBucket: perBucket,
    totalAllocated: Money(totalAllocated, currency),
    undistributed: Money(income.minorUnits - totalAllocated, currency),
    shortfalls: shortfalls,
  );
}
