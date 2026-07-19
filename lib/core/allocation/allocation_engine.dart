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
      AllocationMethod.goalBased => 0,
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

/// Preview a [template] split of [income] — §8.4. Wraps [computeAllocation]
/// with the `unallocated`/`freeAfter` fields the confirm screen needs. Since
/// `computeAllocation` always caps `totalAllocated` at what is available,
/// this preview's `unallocated` is never negative — over-allocation only
/// arises from [editedAllocationPreview], once the user takes over amounts
/// by hand.
AllocationPreview previewAllocation(
    Money income, AllocationTemplate template) {
  final result = computeAllocation(income, template);
  return _preview(
    income: income,
    directions: template.directions,
    perBucket: result.perBucket,
    allocatedTotal: result.totalAllocated,
    shortfall: result.shortfalls,
  );
}

/// Recompute the preview from directly-edited per-direction amounts (the
/// confirm screen's editable fields) instead of the method-driven engine —
/// the user has taken over each direction's amount by hand, so no method is
/// applied and no shortfall is computed against it. A zero or missing entry
/// contributes nothing. Unlike [previewAllocation], the resulting
/// `allocatedTotal` CAN exceed [income] (an over-allocated edit), which is
/// exactly the signal the confirm button uses to disable itself.
AllocationPreview editedAllocationPreview(
  Money income,
  List<AllocationDirection> directions,
  Map<String, Money> edited,
) {
  final currency = income.currency;
  final perBucket = <String, Money>{};
  var totalMinor = 0;
  for (final d in directions) {
    final amount = edited[d.bucketKey];
    if (amount == null || amount.minorUnits <= 0) continue;
    perBucket[d.bucketKey] = amount;
    totalMinor += amount.minorUnits;
  }
  return _preview(
    income: income,
    directions: directions,
    perBucket: perBucket,
    allocatedTotal: Money(totalMinor, currency),
    shortfall: const [],
  );
}

AllocationPreview _preview({
  required Money income,
  required List<AllocationDirection> directions,
  required Map<String, Money> perBucket,
  required Money allocatedTotal,
  required List<Shortfall> shortfall,
}) {
  final currency = income.currency;
  final unallocatedMinor = income.minorUnits - allocatedTotal.minorUnits;
  final freeAfterMinor = unallocatedMinor < 0 ? 0 : unallocatedMinor;
  return AllocationPreview(
    income: income,
    directions: directions,
    perBucket: perBucket,
    allocatedTotal: allocatedTotal,
    unallocated: Money(unallocatedMinor, currency),
    freeAfter: Money(freeAfterMinor, currency),
    shortfall: shortfall,
  );
}
