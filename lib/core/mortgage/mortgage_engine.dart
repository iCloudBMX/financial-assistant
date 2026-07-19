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

DateTime _addMonths(DateTime from, int months) =>
    DateTime(from.year, from.month + months, from.day);

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
