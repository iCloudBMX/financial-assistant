// test/core/mortgage/mortgage_scenarios_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/mortgage/mortgage_engine.dart';

void main() {
  final asOf = DateTime(2026, 1, 1);

  ScenarioResult scenario(ScenarioKind kind, {int extraMonthly = 0, int oneTime = 0, int income = 0}) =>
      computeScenario(
        kind: kind,
        currentPrincipalMinor: 1000000,
        annualRateBp: 1200,
        type: PaymentType.annuity,
        monthlyPaymentMinor: 100000,
        extraMonthlyMinor: extraMonthly,
        oneTimeExtraMinor: oneTime,
        remainingIncomeMinor: income,
        asOf: asOf,
      );

  test('extra monthly closes sooner and saves interest vs baseline', () {
    final base = scenario(ScenarioKind.mandatoryOnly);
    final extra = scenario(ScenarioKind.fixedExtraMonthly, extraMonthly: 100000);
    expect(extra.monthsRemaining, lessThan(base.monthsRemaining));
    expect(extra.interestSavedMinor, greaterThan(0));
    expect(extra.monthsSaved, base.monthsRemaining - extra.monthsRemaining);
    // baseline saves nothing against itself
    expect(base.interestSavedMinor, 0);
    expect(base.monthsSaved, 0);
  });

  test('one-time extra reduces the balance up front', () {
    final base = scenario(ScenarioKind.mandatoryOnly);
    final once = scenario(ScenarioKind.oneTimeExtra, oneTime: 300000);
    expect(once.monthsRemaining, lessThan(base.monthsRemaining));
    expect(once.interestSavedMinor, greaterThan(0));
  });

  test('compareScenarios returns the four kinds, baseline first', () {
    final list = compareScenarios(
      currentPrincipalMinor: 1000000,
      annualRateBp: 1200,
      type: PaymentType.annuity,
      monthlyPaymentMinor: 100000,
      extraMonthlyMinor: 50000,
      oneTimeExtraMinor: 200000,
      remainingIncomeMinor: 150000,
      asOf: asOf,
    );
    expect(list.map((s) => s.kind).toList(), [
      ScenarioKind.mandatoryOnly,
      ScenarioKind.fixedExtraMonthly,
      ScenarioKind.oneTimeExtra,
      ScenarioKind.allRemainingIncome,
    ]);
  });

  test('applyExtraPayment shortenTerm keeps payment, closes sooner', () {
    final base = projectPayoff(
      currentPrincipalMinor: 1000000,
      annualRateBp: 1200,
      type: PaymentType.annuity,
      monthlyPaymentMinor: 100000,
      asOf: asOf,
    );
    final after = applyExtraPayment(
      currentPrincipalMinor: 1000000,
      extraMinor: 300000,
      annualRateBp: 1200,
      type: PaymentType.annuity,
      monthlyPaymentMinor: 100000,
      strategy: PayoffStrategy.shortenTerm,
      asOf: asOf,
    );
    expect(after.monthsRemaining, lessThan(base.monthsRemaining));
    expect(after.isApproximate, isFalse);
  });

  test('applyExtraPayment unclear marks the result approximate', () {
    final after = applyExtraPayment(
      currentPrincipalMinor: 1000000,
      extraMinor: 300000,
      annualRateBp: 1200,
      type: PaymentType.annuity,
      monthlyPaymentMinor: 100000,
      strategy: PayoffStrategy.unclear,
      asOf: asOf,
    );
    expect(after.isApproximate, isTrue);
  });

  test('solvePaymentForTerm finds a payment that closes within the term', () {
    final pay = solvePaymentForTerm(
        principalMinor: 1000000, annualRateBp: 1200, months: 12);
    final p = projectPayoff(
      currentPrincipalMinor: 1000000,
      annualRateBp: 1200,
      type: PaymentType.annuity,
      monthlyPaymentMinor: pay,
      asOf: asOf,
    );
    expect(p.neverCloses, isFalse);
    expect(p.monthsRemaining, lessThanOrEqualTo(12));
  });

  test('differential requiredMonthly includes first-month interest', () {
    final res = computeScenario(
      kind: ScenarioKind.mandatoryOnly,
      currentPrincipalMinor: 1000000,
      annualRateBp: 1200,
      type: PaymentType.differential,
      monthlyPaymentMinor: 0,
      monthlyPrincipalMinor: 100000,
      asOf: asOf,
    );
    // first-month interest on 1_000_000 at 1200bp = 10_000
    // requiredMonthly = 100_000 principal + 0 extra + 10_000 interest = 110_000
    expect(res.requiredMonthlyMinor, 110000);
    expect(res.requiredMonthlyMinor, greaterThan(100000));
  });

  test('differential lowerPayment is approximate; shortenTerm is not', () {
    final lower = applyExtraPayment(
      currentPrincipalMinor: 1000000,
      extraMinor: 300000,
      annualRateBp: 1200,
      type: PaymentType.differential,
      monthlyPaymentMinor: 0,
      monthlyPrincipalMinor: 100000,
      strategy: PayoffStrategy.lowerPayment,
      asOf: asOf,
    );
    expect(lower.isApproximate, isTrue);

    final shorten = applyExtraPayment(
      currentPrincipalMinor: 1000000,
      extraMinor: 300000,
      annualRateBp: 1200,
      type: PaymentType.differential,
      monthlyPaymentMinor: 0,
      monthlyPrincipalMinor: 100000,
      strategy: PayoffStrategy.shortenTerm,
      asOf: asOf,
    );
    expect(shorten.isApproximate, isFalse);
  });
}
