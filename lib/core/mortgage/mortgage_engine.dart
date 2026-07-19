// lib/core/mortgage/mortgage_engine.dart

import '../money/money.dart';

/// How each period's principal/interest split is derived (§13.1).
enum PaymentType { annuity, differential, custom }

/// How the bank treats an extra payment (§13.5). `unclear` marks results
/// approximate.
enum PayoffStrategy { shortenTerm, lowerPayment, unclear }

/// The result of projecting a loan forward to payoff. Integer minor units only.
class MortgageProjection {
  final DateTime? payoffDate; // null when [neverCloses]
  final int monthsRemaining;
  final int totalRemainingInterestMinor;
  final bool neverCloses; // payment never exceeds interest -> balance never falls
  final bool isApproximate; // §13.5 "unclear" strategy / custom estimate
  const MortgageProjection({
    required this.payoffDate,
    required this.monthsRemaining,
    required this.totalRemainingInterestMinor,
    required this.neverCloses,
    required this.isApproximate,
  });
}

const int _monthCap = 1200; // 100 years — a runaway guard, never a real payoff.

/// One month's interest on [balanceMinor] at [annualRateBp] basis points,
/// rounded half-up. `120000 = 12 months × 10000 bp`. No float — the product
/// stays in 64-bit range for realistic balances.
int monthlyInterestMinor(int balanceMinor, int annualRateBp) {
  if (balanceMinor <= 0 || annualRateBp <= 0) return 0;
  return (balanceMinor * annualRateBp + 60000) ~/ 120000;
}

/// Advance [from] by [months] calendar months, clamping the day to the target
/// month's last day (Jan 31 + 1 month -> Feb 28/29, never overflowing into the
/// following month).
DateTime addMonths(DateTime from, int months) {
  final totalMonths = from.month - 1 + months;
  final year = from.year + totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day; // day 0 of next month = last day of this month
  final day = from.day < lastDay ? from.day : lastDay;
  return DateTime(year, month, day);
}

/// Amortize [currentPrincipalMinor] forward to zero. For [PaymentType.annuity]
/// and [PaymentType.custom] the fixed total is [monthlyPaymentMinor] (custom is
/// an estimate — mark [isApproximate]); for [PaymentType.differential] the fixed
/// principal is [monthlyPrincipalMinor]. Returns [MortgageProjection.neverCloses]
/// when an annuity payment never exceeds the interest.
MortgageProjection projectPayoff({
  required int currentPrincipalMinor,
  required int annualRateBp,
  required PaymentType type,
  required int monthlyPaymentMinor,
  int monthlyPrincipalMinor = 0,
  required DateTime asOf,
  bool isApproximate = false,
}) {
  if (currentPrincipalMinor <= 0) {
    return MortgageProjection(
      payoffDate: asOf,
      monthsRemaining: 0,
      totalRemainingInterestMinor: 0,
      neverCloses: false,
      isApproximate: isApproximate,
    );
  }
  var balance = currentPrincipalMinor;
  var totalInterest = 0;
  var months = 0;
  while (balance > 0 && months < _monthCap) {
    final interest = monthlyInterestMinor(balance, annualRateBp);
    var principal = type == PaymentType.differential
        ? monthlyPrincipalMinor
        : (monthlyPaymentMinor - interest);
    if (principal <= 0) {
      return MortgageProjection(
        payoffDate: null,
        monthsRemaining: 0,
        totalRemainingInterestMinor: totalInterest,
        neverCloses: true,
        isApproximate: isApproximate,
      );
    }
    if (principal > balance) principal = balance; // final month truncates
    totalInterest += interest;
    balance -= principal;
    months += 1;
  }
  if (balance > 0) {
    return MortgageProjection(
      payoffDate: null,
      monthsRemaining: months,
      totalRemainingInterestMinor: totalInterest,
      neverCloses: true,
      isApproximate: isApproximate,
    );
  }
  return MortgageProjection(
    payoffDate: addMonths(asOf, months),
    monthsRemaining: months,
    totalRemainingInterestMinor: totalInterest,
    neverCloses: false,
    isApproximate: isApproximate,
  );
}

/// The §13.6 scenarios.
enum ScenarioKind { mandatoryOnly, fixedExtraMonthly, oneTimeExtra, allRemainingIncome }

/// One §13.6 scenario row, measured against the mandatory-only baseline.
class ScenarioResult {
  final ScenarioKind kind;
  final DateTime? payoffDate;
  final int monthsRemaining;
  final int totalInterestMinor;
  final int interestSavedMinor; // baseline interest − this interest (>=0)
  final int monthsSaved; // baseline months − this months (>=0)
  final int requiredMonthlyMinor; // total monthly outlay for this scenario
  final bool neverCloses;
  final bool isApproximate;
  const ScenarioResult({
    required this.kind,
    required this.payoffDate,
    required this.monthsRemaining,
    required this.totalInterestMinor,
    required this.interestSavedMinor,
    required this.monthsSaved,
    required this.requiredMonthlyMinor,
    required this.neverCloses,
    required this.isApproximate,
  });
}

int _max0(int v) => v < 0 ? 0 : v;

/// Project with an optional recurring [extraMonthlyMinor] added to the annuity
/// principal each month (differential just adds it to the fixed principal).
MortgageProjection _projectWithExtra({
  required int principalMinor,
  required int annualRateBp,
  required PaymentType type,
  required int monthlyPaymentMinor,
  required int monthlyPrincipalMinor,
  required int extraMonthlyMinor,
  required DateTime asOf,
}) =>
    projectPayoff(
      currentPrincipalMinor: principalMinor,
      annualRateBp: annualRateBp,
      type: type,
      monthlyPaymentMinor: monthlyPaymentMinor + extraMonthlyMinor,
      monthlyPrincipalMinor: monthlyPrincipalMinor + extraMonthlyMinor,
      asOf: asOf,
    );

ScenarioResult computeScenario({
  required ScenarioKind kind,
  required int currentPrincipalMinor,
  required int annualRateBp,
  required PaymentType type,
  required int monthlyPaymentMinor,
  int monthlyPrincipalMinor = 0,
  int extraMonthlyMinor = 0,
  int oneTimeExtraMinor = 0,
  int remainingIncomeMinor = 0,
  required DateTime asOf,
}) {
  final baseline = _projectWithExtra(
    principalMinor: currentPrincipalMinor,
    annualRateBp: annualRateBp,
    type: type,
    monthlyPaymentMinor: monthlyPaymentMinor,
    monthlyPrincipalMinor: monthlyPrincipalMinor,
    extraMonthlyMinor: 0,
    asOf: asOf,
  );

  int startBalance = currentPrincipalMinor;
  int extra = 0;
  switch (kind) {
    case ScenarioKind.mandatoryOnly:
      break;
    case ScenarioKind.fixedExtraMonthly:
      extra = extraMonthlyMinor;
    case ScenarioKind.oneTimeExtra:
      startBalance = _max0(currentPrincipalMinor - oneTimeExtraMinor);
    case ScenarioKind.allRemainingIncome:
      extra = remainingIncomeMinor;
  }

  final p = _projectWithExtra(
    principalMinor: startBalance,
    annualRateBp: annualRateBp,
    type: type,
    monthlyPaymentMinor: monthlyPaymentMinor,
    monthlyPrincipalMinor: monthlyPrincipalMinor,
    extraMonthlyMinor: extra,
    asOf: asOf,
  );

  final requiredMonthly = type == PaymentType.differential
      ? monthlyPrincipalMinor + extra + monthlyInterestMinor(startBalance, annualRateBp)
      : monthlyPaymentMinor + extra;

  return ScenarioResult(
    kind: kind,
    payoffDate: p.payoffDate,
    monthsRemaining: p.monthsRemaining,
    totalInterestMinor: p.totalRemainingInterestMinor,
    interestSavedMinor:
        _max0(baseline.totalRemainingInterestMinor - p.totalRemainingInterestMinor),
    monthsSaved: _max0(baseline.monthsRemaining - p.monthsRemaining),
    requiredMonthlyMinor: requiredMonthly,
    neverCloses: p.neverCloses,
    isApproximate: p.isApproximate,
  );
}

List<ScenarioResult> compareScenarios({
  required int currentPrincipalMinor,
  required int annualRateBp,
  required PaymentType type,
  required int monthlyPaymentMinor,
  int monthlyPrincipalMinor = 0,
  int extraMonthlyMinor = 0,
  int oneTimeExtraMinor = 0,
  int remainingIncomeMinor = 0,
  required DateTime asOf,
}) =>
    [
      for (final kind in ScenarioKind.values)
        computeScenario(
          kind: kind,
          currentPrincipalMinor: currentPrincipalMinor,
          annualRateBp: annualRateBp,
          type: type,
          monthlyPaymentMinor: monthlyPaymentMinor,
          monthlyPrincipalMinor: monthlyPrincipalMinor,
          extraMonthlyMinor: extraMonthlyMinor,
          oneTimeExtraMinor: oneTimeExtraMinor,
          remainingIncomeMinor: remainingIncomeMinor,
          asOf: asOf,
        ),
    ];

/// §13.4/§13.5: apply a one-off [extraMinor] to the principal then reproject.
/// `shortenTerm` keeps the payment (fewer months); `lowerPayment` keeps the
/// baseline remaining term and solves a smaller payment; `unclear` computes
/// `shortenTerm` but flags the result approximate.
MortgageProjection applyExtraPayment({
  required int currentPrincipalMinor,
  required int extraMinor,
  required int annualRateBp,
  required PaymentType type,
  required int monthlyPaymentMinor,
  int monthlyPrincipalMinor = 0,
  required PayoffStrategy strategy,
  required DateTime asOf,
}) {
  final newBalance = _max0(currentPrincipalMinor - extraMinor);
  if (strategy == PayoffStrategy.lowerPayment && type != PaymentType.differential) {
    final baseline = projectPayoff(
      currentPrincipalMinor: currentPrincipalMinor,
      annualRateBp: annualRateBp,
      type: type,
      monthlyPaymentMinor: monthlyPaymentMinor,
      asOf: asOf,
    );
    final months = baseline.neverCloses ? _monthCap : baseline.monthsRemaining;
    final pay = solvePaymentForTerm(
        principalMinor: newBalance, annualRateBp: annualRateBp, months: months);
    return projectPayoff(
      currentPrincipalMinor: newBalance,
      annualRateBp: annualRateBp,
      type: type,
      monthlyPaymentMinor: pay,
      asOf: asOf,
    );
  }
  return projectPayoff(
    currentPrincipalMinor: newBalance,
    annualRateBp: annualRateBp,
    type: type,
    monthlyPaymentMinor: monthlyPaymentMinor,
    monthlyPrincipalMinor: monthlyPrincipalMinor,
    asOf: asOf,
    isApproximate: strategy == PayoffStrategy.unclear
        || (strategy == PayoffStrategy.lowerPayment && type == PaymentType.differential),
  );
}

/// §6.9/§13.3: how the mortgage payment sheet derives or accepts the split
/// between principal and interest for one payment.
enum MortgageSplitMode { auto, manual }

/// The mortgage payment sheet's derived UI state (§6.9). Pure and
/// Flutter-free — the sheet renders this, it never computes it itself.
/// [difference] is `total − (principal + interest)`; [canSave] is false
/// whenever a portion is negative, the parts exceed the total, or they
/// simply do not add up to it.
class MortgagePaymentSplitState {
  final MortgageSplitMode mode;
  final Money total;
  final Money principal;
  final Money interest;
  final Money difference;
  final bool canSave;
  const MortgagePaymentSplitState({
    required this.mode,
    required this.total,
    required this.principal,
    required this.interest,
    required this.difference,
    required this.canSave,
  });
}

/// Auto split (§6.9): interest is a fact of the current balance and rate —
/// derived FIRST, directly from [currentPrincipalMinor]/[annualRateBp] via
/// [monthlyInterestMinor] — and principal absorbs whatever is left of
/// [total]. This ordering is the correctness invariant: principal is never
/// computed on its own and then reduced by interest a second time, so
/// interest can never act as a reduction applied to the principal figure.
///
/// Principal is additionally bounded by the outstanding balance: a payment
/// larger than `balance + interest` would drive `currentPrincipal` negative
/// after the write. Such an over-payoff is NOT writable — §6.9 keeps save
/// disabled when the split "exceeds" — so the principal is clamped to the
/// outstanding balance and the leftover surfaces as a positive [difference]
/// with `canSave == false` (mirroring the Manual unbalanced state). When the
/// payment is at or below payoff, `principal + interest == total` exactly.
MortgagePaymentSplitState deriveAutoSplit({
  required Money total,
  required int currentPrincipalMinor,
  required int annualRateBp,
}) {
  final c = total.currency;
  final totalMinor = total.minorUnits;
  if (totalMinor <= 0) {
    return MortgagePaymentSplitState(
      mode: MortgageSplitMode.auto,
      total: total,
      principal: Money.zero(c),
      interest: Money.zero(c),
      difference: Money.zero(c),
      canSave: false,
    );
  }
  final rawInterest = monthlyInterestMinor(currentPrincipalMinor, annualRateBp);
  // The mandatory payment can, in principle, undershoot a month's interest
  // (a "neverCloses" plan) — clamp so principal never goes negative.
  final interestMinor = rawInterest > totalMinor ? totalMinor : rawInterest;
  final rawPrincipalMinor = totalMinor - interestMinor;
  // Principal can never exceed the outstanding balance (the final payment
  // pays it to exactly zero). Anything beyond that is an over-payoff.
  final maxPrincipalMinor = currentPrincipalMinor < 0 ? 0 : currentPrincipalMinor;
  final overPayoff = rawPrincipalMinor > maxPrincipalMinor;
  final principalMinor = overPayoff ? maxPrincipalMinor : rawPrincipalMinor;
  final diffMinor = totalMinor - principalMinor - interestMinor;
  return MortgagePaymentSplitState(
    mode: MortgageSplitMode.auto,
    total: total,
    principal: Money(principalMinor, c),
    interest: Money(interestMinor, c),
    difference: Money(diffMinor, c),
    canSave: !overPayoff,
  );
}

/// Manual split (§6.9): the user enters both portions directly. [difference]
/// surfaces exactly how far the live equation is from balancing; [canSave]
/// requires both portions non-negative AND the equation to balance exactly
/// (covers "negative", "exceeds the total", and "does not balance" from the
/// design spec in one check).
MortgagePaymentSplitState manualSplit({
  required Money total,
  required Money principal,
  required Money interest,
}) {
  final diffMinor =
      total.minorUnits - principal.minorUnits - interest.minorUnits;
  final nonNegative = principal.minorUnits >= 0 && interest.minorUnits >= 0;
  return MortgagePaymentSplitState(
    mode: MortgageSplitMode.manual,
    total: total,
    principal: principal,
    interest: interest,
    difference: Money(diffMinor, total.currency),
    canSave: total.minorUnits > 0 && nonNegative && diffMinor == 0,
  );
}

/// Smallest integer monthly annuity payment that amortizes [principalMinor]
/// within [months]. Binary search over the payment — integer-only, no `pow`.
int solvePaymentForTerm({
  required int principalMinor,
  required int annualRateBp,
  required int months,
}) {
  if (principalMinor <= 0 || months <= 0) return 0;
  var lo = 1;
  var hi = principalMinor + monthlyInterestMinor(principalMinor, annualRateBp) + 1;
  while (lo < hi) {
    final mid = lo + (hi - lo) ~/ 2;
    final p = projectPayoff(
      currentPrincipalMinor: principalMinor,
      annualRateBp: annualRateBp,
      type: PaymentType.annuity,
      monthlyPaymentMinor: mid,
      asOf: DateTime(2000),
    );
    if (!p.neverCloses && p.monthsRemaining <= months) {
      hi = mid;
    } else {
      lo = mid + 1;
    }
  }
  return lo;
}
