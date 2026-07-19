import '../money/money.dart';

/// §10.4 category budget status. `noLimit` when the category has no limit set.
enum CategoryLimitStatus { noLimit, safe, near, over }

/// Status of [spent] against an optional [limit].
///
/// `over`  when spent > limit.
/// `near`  when spent >= [nearThresholdBp] basis points of the limit (default
///         8500 = 85%).
/// `safe`  otherwise. A null limit yields `noLimit`.
///
/// Integer-only: the near test is `spent*10000 >= limit*nearThresholdBp`, so
/// no floating-point ratio is ever formed.
CategoryLimitStatus categoryStatus(Money spent, Money? limit,
    {int nearThresholdBp = 8500}) {
  if (limit == null) return CategoryLimitStatus.noLimit;
  if (spent.minorUnits > limit.minorUnits) return CategoryLimitStatus.over;
  if (spent.minorUnits * 10000 >= limit.minorUnits * nearThresholdBp) {
    return CategoryLimitStatus.near;
  }
  return CategoryLimitStatus.safe;
}

/// Signed remaining budget: `limit − spent` (positive = under budget).
Money categoryRemaining(Money spent, Money limit) => limit.subtract(spent);

/// Signed deviation: `spent − limit` (positive = over budget). §10.3.
Money categoryDeviation(Money spent, Money limit) => spent.subtract(limit);
