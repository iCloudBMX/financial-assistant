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
