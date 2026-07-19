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

    test('principal + interest always equals total', () {
      for (final rateBp in [0, 100, 1800, 3600]) {
        for (final balance in [0, 1, 999999, 250000000]) {
          final split = deriveAutoSplit(
            total: m(5000000),
            currentPrincipalMinor: balance,
            annualRateBp: rateBp,
          );
          expect(split.principal.minorUnits + split.interest.minorUnits,
              split.total.minorUnits,
              reason: 'rate=$rateBp balance=$balance');
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
