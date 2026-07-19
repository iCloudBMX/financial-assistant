import '../money/money.dart';

/// How a direction claims money from an income. `goalBased` is resolved to a
/// fixedAmount in the provider layer (SP3) before computeAllocation runs.
enum AllocationMethod { fixedAmount, percentage, remaining, goalBased }

/// One line of an allocation template: send money to [bucketKey] via [method].
/// [amount] is set for `fixedAmount`; [percentBp] (basis points) for
/// `percentage`; neither for `remaining`.
class AllocationDirection {
  final String bucketKey;
  final AllocationMethod method;
  final Money? amount;
  final int? percentBp;
  const AllocationDirection({
    required this.bucketKey,
    required this.method,
    this.amount,
    this.percentBp,
  });
}

/// The single reusable template; [directions] are in priority order (§8.3).
class AllocationTemplate {
  final List<AllocationDirection> directions;
  const AllocationTemplate(this.directions);
}

/// A direction that could not be fully funded (§8.5).
class Shortfall {
  final String bucketKey;
  final Money requested;
  final Money funded;
  const Shortfall(this.bucketKey, this.requested, this.funded);
  Money get shortBy => requested.subtract(funded);
}

/// The outcome of splitting one income across the template.
class AllocationResult {
  final Map<String, Money> perBucket;
  final Money totalAllocated;
  final Money undistributed;
  final List<Shortfall> shortfalls;
  const AllocationResult({
    required this.perBucket,
    required this.totalAllocated,
    required this.undistributed,
    required this.shortfalls,
  });
}

/// The full pre-commit preview shown before an allocation split is confirmed
/// (§8.4): total income, each direction in priority order, the funded
/// per-bucket amounts, the funded total, what remains unallocated, what
/// stays free once this commits, and any directions the income could not
/// fully fund (§8.5).
class AllocationPreview {
  final Money income;
  final List<AllocationDirection> directions;
  final Map<String, Money> perBucket;
  final Money allocatedTotal;

  /// `income − allocatedTotal`. Negative when an edited total exceeds
  /// income — the sign the UI uses to disable confirm (no over-allocation).
  final Money unallocated;

  /// `max(0, unallocated)` — the free balance once this split commits;
  /// unlike [unallocated], never negative.
  final Money freeAfter;

  final List<Shortfall> shortfall;

  const AllocationPreview({
    required this.income,
    required this.directions,
    required this.perBucket,
    required this.allocatedTotal,
    required this.unallocated,
    required this.freeAfter,
    required this.shortfall,
  });
}
