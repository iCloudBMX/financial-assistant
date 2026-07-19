// lib/core/mortgage/mortgage_engine.dart

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

DateTime _addMonths(DateTime from, int months) {
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
    payoffDate: _addMonths(asOf, months),
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
