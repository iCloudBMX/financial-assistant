// test/core/mortgage/mortgage_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/mortgage/mortgage_engine.dart';

void main() {
  test('monthlyInterestMinor rounds half-up', () {
    // 100_000_000 @ 1850bp -> 100_000_000*1850/120000 = 1_541_666.66..  -> 1_541_667
    expect(monthlyInterestMinor(100000000, 1850), 1541667);
    // zero rate -> zero interest
    expect(monthlyInterestMinor(100000000, 0), 0);
  });

  test('a zero balance is already paid off', () {
    final p = projectPayoff(
      currentPrincipalMinor: 0,
      annualRateBp: 1800,
      type: PaymentType.annuity,
      monthlyPaymentMinor: 1000000,
      asOf: DateTime(2026, 1, 1),
    );
    expect(p.monthsRemaining, 0);
    expect(p.payoffDate, DateTime(2026, 1, 1));
    expect(p.neverCloses, isFalse);
  });

  test('annuity amortizes to zero and reports months + total interest', () {
    // 1_000_000 @ 1200bp (1%/mo), payment 100_000.
    // Hand-checked: closes in 11 months, last payment truncated to balance.
    final p = projectPayoff(
      currentPrincipalMinor: 1000000,
      annualRateBp: 1200,
      type: PaymentType.annuity,
      monthlyPaymentMinor: 100000,
      asOf: DateTime(2026, 1, 1),
    );
    expect(p.neverCloses, isFalse);
    expect(p.monthsRemaining, 11);
    expect(p.payoffDate, DateTime(2026, 12, 1));
    expect(p.totalRemainingInterestMinor, greaterThan(0));
  });

  test('annuity whose payment <= first interest never closes', () {
    // 1_000_000 @ 1200bp -> first interest 10_000; payment 8_000 < 10_000.
    final p = projectPayoff(
      currentPrincipalMinor: 1000000,
      annualRateBp: 1200,
      type: PaymentType.annuity,
      monthlyPaymentMinor: 8000,
      asOf: DateTime(2026, 1, 1),
    );
    expect(p.neverCloses, isTrue);
    expect(p.payoffDate, isNull);
  });

  test('differential uses a fixed principal each month', () {
    // principal 100_000/mo on 1_000_000 -> exactly 10 months regardless of rate.
    final p = projectPayoff(
      currentPrincipalMinor: 1000000,
      annualRateBp: 1800,
      type: PaymentType.differential,
      monthlyPaymentMinor: 0,
      monthlyPrincipalMinor: 100000,
      asOf: DateTime(2026, 1, 1),
    );
    expect(p.monthsRemaining, 10);
    expect(p.payoffDate, DateTime(2026, 11, 1));
    expect(p.neverCloses, isFalse);
  });

  test('payoffDate clamps to last day of month when asOf is a month-end', () {
    // asOf Jan 31 + 10 months (differential, 100_000/mo on 1_000_000).
    // Target month is November (30 days); day 31 must clamp to 30, NOT
    // overflow into December. payoffDate must stay in the projected month
    // consistent with monthsRemaining = 10.
    final p = projectPayoff(
      currentPrincipalMinor: 1000000,
      annualRateBp: 1800,
      type: PaymentType.differential,
      monthlyPaymentMinor: 0,
      monthlyPrincipalMinor: 100000,
      asOf: DateTime(2026, 1, 31),
    );
    expect(p.monthsRemaining, 10);
    expect(p.payoffDate, DateTime(2026, 11, 30));
    expect(p.payoffDate!.month, 11); // did not overflow into December
    expect(p.neverCloses, isFalse);
  });
}
