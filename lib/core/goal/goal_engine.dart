import '../money/money.dart';

/// Everything the goal progress computation needs (§12.4). Pure inputs — no
/// Flutter/Drift. `saved` is the derived Σ of signed contributions.
class GoalProgressInputs {
  final Money saved;
  final Money target;
  final DateTime startDate;
  final DateTime? targetDate;
  final DateTime asOf;
  const GoalProgressInputs({
    required this.saved,
    required this.target,
    required this.startDate,
    this.targetDate,
    required this.asOf,
  });
}

/// The §12.4 goal-card figures. Integer minor units only.
class GoalProgress {
  final Money saved;
  final Money target;
  final Money remaining; // max(0, target − saved)
  final int percentBp; // 0..10000
  final int? daysToTargetDate; // null when no deadline
  final DateTime? projectedDate; // null when no rate yet
  final Money? requiredMonthly; // null when no deadline
  final bool? onTrack; // null when either date is unknown
  const GoalProgress({
    required this.saved,
    required this.target,
    required this.remaining,
    required this.percentBp,
    required this.daysToTargetDate,
    required this.projectedDate,
    required this.requiredMonthly,
    required this.onTrack,
  });
}

int _max0(int v) => v < 0 ? 0 : v;
int _ceilDiv(int a, int b) => (a + b - 1) ~/ b; // a>=0, b>=1

/// §12.4 "joriy sur'atda targetga yetish sanasi": average-rate extrapolation
/// from the goal's start. Null when nothing is saved yet (no rate).
DateTime? projectedCompletionDate({
  required Money saved,
  required Money remaining,
  required DateTime startDate,
  required DateTime asOf,
}) {
  if (remaining.minorUnits <= 0) return asOf; // already complete
  if (saved.minorUnits <= 0) return null; // no rate yet
  final elapsedDays = _max0(asOf.difference(startDate).inDays);
  final days = elapsedDays < 1 ? 1 : elapsedDays;
  // remaining × elapsedDays ÷ saved  (integer days at the average rate)
  final projectedDaysLeft = remaining.minorUnits * days ~/ saved.minorUnits;
  return asOf.add(Duration(days: projectedDaysLeft));
}

/// §12.4 + §8.2: the monthly amount needed to hit target by [targetDate].
/// Null when there is no deadline. A past deadline funds the whole remainder
/// now (months remaining floored at 1).
Money? requiredMonthlyContribution({
  required Money remaining,
  required DateTime? targetDate,
  required DateTime asOf,
}) {
  if (targetDate == null) return null;
  final c = remaining.currency;
  if (remaining.minorUnits <= 0) return Money(0, c);
  final rawMonths = (targetDate.year * 12 + targetDate.month) -
      (asOf.year * 12 + asOf.month) +
      (targetDate.day > asOf.day ? 1 : 0);
  final months = rawMonths < 1 ? 1 : rawMonths;
  return Money(_ceilDiv(remaining.minorUnits, months), c);
}

GoalProgress computeGoalProgress(GoalProgressInputs i) {
  final c = i.target.currency;
  final remainingMinor = _max0(i.target.minorUnits - i.saved.minorUnits);
  final remaining = Money(remainingMinor, c);
  final percentBp = i.target.minorUnits <= 0
      ? 10000
      : (i.saved.minorUnits * 10000 ~/ i.target.minorUnits).clamp(0, 10000);
  final daysToTarget = i.targetDate?.difference(i.asOf).inDays;
  final projected = projectedCompletionDate(
    saved: i.saved,
    remaining: remaining,
    startDate: i.startDate,
    asOf: i.asOf,
  );
  final required = requiredMonthlyContribution(
    remaining: remaining,
    targetDate: i.targetDate,
    asOf: i.asOf,
  );
  final onTrack = (i.targetDate != null && projected != null)
      ? !projected.isAfter(i.targetDate!)
      : null;
  return GoalProgress(
    saved: i.saved,
    target: i.target,
    remaining: remaining,
    percentBp: percentBp,
    daysToTargetDate: daysToTarget,
    projectedDate: projected,
    requiredMonthly: required,
    onTrack: onTrack,
  );
}
