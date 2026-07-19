import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/mortgage/mortgage_engine.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => Money(v, uzs);

  group('deriveAutoSplit', () {
    test('derives interest from balance/rate and principal absorbs the rest',
        () {
      final split = deriveAutoSplit(
        total: m(5000000),
        currentPrincipalMinor: 100000000,
        annualRateBp: 1800,
      );
      expect(split.mode, MortgageSplitMode.auto);
      // monthlyInterestMinor(100000000, 1800) = 1500000 (half-up rounded).
      expect(split.interest, m(1500000));
      expect(split.principal, m(3500000));
      expect(split.principal.minorUnits + split.interest.minorUnits,
          split.total.minorUnits);
      expect(split.difference, m(0));
      expect(split.canSave, isTrue);
    });

    test(
        'a savable split always balances (principal + interest == total) and '
        'principal never exceeds the outstanding balance', () {
      for (final rateBp in [0, 100, 1800, 3600]) {
        for (final balance in [0, 1, 999999, 250000000]) {
          final split = deriveAutoSplit(
            total: m(5000000),
            currentPrincipalMinor: balance,
            annualRateBp: rateBp,
          );
          // Principal is bounded by the outstanding balance in every case,
          // so the write can never drive currentPrincipal negative.
          expect(split.principal.minorUnits, lessThanOrEqualTo(balance < 0 ? 0 : balance),
              reason: 'rate=$rateBp balance=$balance principal exceeds outstanding');
          // A savable split balances exactly; an over-payoff is instead
          // surfaced as a positive difference with canSave == false.
          if (split.canSave) {
            expect(split.principal.minorUnits + split.interest.minorUnits,
                split.total.minorUnits,
                reason: 'rate=$rateBp balance=$balance savable but unbalanced');
          } else {
            expect(split.difference.minorUnits, greaterThan(0),
                reason: 'rate=$rateBp balance=$balance over-payoff not surfaced');
          }
        }
      }
    });

    test(
        'a huge interest fact clamps principal to zero instead of going '
        'negative — interest never reduces principal below zero', () {
      final split = deriveAutoSplit(
        total: m(1000000),
        currentPrincipalMinor: 900000000, // interest alone dwarfs the payment
        annualRateBp: 3600,
      );
      expect(split.principal, m(0));
      expect(split.interest, m(1000000)); // clamped to the total
      expect(split.principal.minorUnits + split.interest.minorUnits,
          split.total.minorUnits);
      expect(split.principal.minorUnits, greaterThanOrEqualTo(0));
    });

    test('interest is independent of any principal figure — it is derived '
        'purely from balance and rate, never from a prior principal value',
        () {
      // Same balance/rate, different totals: interest stays identical both
      // times, proving principal never feeds back into the interest calc.
      final a = deriveAutoSplit(
          total: m(5000000), currentPrincipalMinor: 100000000, annualRateBp: 1800);
      final b = deriveAutoSplit(
          total: m(9000000), currentPrincipalMinor: 100000000, annualRateBp: 1800);
      expect(a.interest, b.interest);
    });

    test('a zero or negative total cannot save', () {
      final split = deriveAutoSplit(
        total: m(0),
        currentPrincipalMinor: 100000000,
        annualRateBp: 1800,
      );
      expect(split.canSave, isFalse);
    });

    test(
        'the exact final payment pays principal to zero and is savable '
        '(principal == outstanding, balances)', () {
      // Outstanding 3,000,000 at 0% → the whole payment is principal.
      final split = deriveAutoSplit(
        total: m(3000000),
        currentPrincipalMinor: 3000000,
        annualRateBp: 0,
      );
      expect(split.interest, m(0));
      expect(split.principal, m(3000000)); // exactly the outstanding balance
      expect(split.difference, m(0));
      expect(split.canSave, isTrue);
    });

    test(
        'an over-payoff clamps principal to the outstanding balance, never '
        'exceeds it, and disables save (option b)', () {
      // Outstanding 3,000,000 at 0%, but the user tries to pay 5,000,000.
      final split = deriveAutoSplit(
        total: m(5000000),
        currentPrincipalMinor: 3000000,
        annualRateBp: 0,
      );
      // Principal is clamped to the outstanding balance — NEVER above it, so
      // currentPrincipal (balance − principal) cannot go negative.
      expect(split.principal, m(3000000));
      expect(split.principal.minorUnits,
          lessThanOrEqualTo(3000000)); // never exceeds outstanding
      // The 2,000,000 excess surfaces as a positive difference...
      expect(split.difference, m(2000000));
      // ...and the over-payoff is not writable.
      expect(split.canSave, isFalse);
    });

    test('over-payoff with interest still bounds principal to outstanding',
        () {
      // Outstanding 1,000,000 at 1800bp → interest 15,000; a 5,000,000
      // payment would otherwise book 4,985,000 principal against a
      // 1,000,000 balance.
      final split = deriveAutoSplit(
        total: m(5000000),
        currentPrincipalMinor: 1000000,
        annualRateBp: 1800,
      );
      expect(split.interest, m(15000));
      expect(split.principal, m(1000000)); // clamped to outstanding
      expect(split.principal.minorUnits, lessThanOrEqualTo(1000000));
      expect(split.canSave, isFalse);
    });

    test('paying an already-paid-off mortgage (balance 0) cannot save', () {
      final split = deriveAutoSplit(
        total: m(1000000),
        currentPrincipalMinor: 0,
        annualRateBp: 1800,
      );
      expect(split.principal, m(0));
      expect(split.canSave, isFalse);
    });
  });

  group('manualSplit', () {
    test('a balanced manual split enables save with zero difference', () {
      final split = manualSplit(
        total: m(5000000),
        principal: m(3500000),
        interest: m(1500000),
      );
      expect(split.mode, MortgageSplitMode.manual);
      expect(split.difference, m(0));
      expect(split.canSave, isTrue);
    });

    test('an unbalanced manual split reports the exact difference and '
        'disables save', () {
      final split = manualSplit(
        total: m(5000000),
        principal: m(3000000),
        interest: m(1000000), // sums to 4,000,000 — 1,000,000 short
      );
      expect(split.difference, m(1000000));
      expect(split.canSave, isFalse);
    });

    test('parts exceeding the total disables save (negative difference)',
        () {
      final split = manualSplit(
        total: m(5000000),
        principal: m(4000000),
        interest: m(2000000), // sums to 6,000,000 — over by 1,000,000
      );
      expect(split.difference, m(-1000000));
      expect(split.canSave, isFalse);
    });

    test('a negative portion disables save even if the sum balances', () {
      final split = manualSplit(
        total: m(5000000),
        principal: m(6000000),
        interest: m(-1000000),
      );
      expect(split.difference, m(0)); // sums to total...
      expect(split.canSave, isFalse); // ...but a negative part still blocks it
    });

    test('a zero total cannot save even with a balanced zero split', () {
      final split = manualSplit(total: m(0), principal: m(0), interest: m(0));
      expect(split.canSave, isFalse);
    });
  });
}
