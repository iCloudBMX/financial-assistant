import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';

void main() {
  final uzs = CurrencyRegistry.uzs;
  final usd = CurrencyRegistry.usd;

  test('add sums minor units of same currency', () {
    expect(Money(1000, uzs).add(Money(500, uzs)), Money(1500, uzs));
  });

  test('subtract can go negative', () {
    final r = Money(500, uzs).subtract(Money(800, uzs));
    expect(r.minorUnits, -300);
    expect(r.isNegative, isTrue);
  });

  test('add throws on currency mismatch', () {
    expect(
      () => Money(1, uzs).add(Money(1, usd)),
      throwsA(isA<CurrencyMismatchError>()),
    );
  });

  test('tryParse reads grouped UZS input', () {
    expect(Money.tryParse('1 234 567', uzs), Money(1234567, uzs));
  });

  test('tryParse reads USD decimals into minor units', () {
    expect(Money.tryParse('12.34', usd), Money(1234, usd));
  });

  test('tryParse returns null on garbage', () {
    expect(Money.tryParse('abc', uzs), isNull);
  });

  test('tryParse returns null instead of throwing on integer overflow', () {
    const overflow = '99999999999999999999999999999999999999999999999999';
    expect(Money.tryParse(overflow, uzs), isNull);
  });

  test('format groups thousands and places symbol after for UZS', () {
    expect(Money(1234567, uzs).format(), "1 234 567 so'm");
  });

  test('format shows two decimals and leading symbol for USD', () {
    expect(Money(1234, usd).format(), r'$12.34');
  });

  test('compareTo orders by amount', () {
    expect(Money(100, uzs).compareTo(Money(200, uzs)), isNegative);
  });

  test('tryParse rejects double sign and misplaced sign', () {
    expect(Money.tryParse('--12', uzs), isNull);
    expect(Money.tryParse('12.-34', usd), isNull);
    expect(Money.tryParse('1-2', uzs), isNull);
    expect(Money.tryParse('+12', uzs), isNull);
  });

  test('tryParse still accepts a single leading minus', () {
    expect(Money.tryParse('-12.34', usd), Money(-1234, usd));
  });

  test('formatNumber round-trips through tryParse and carries no symbol', () {
    final samples = [
      Money(1234567, uzs), // grouped, no decimals
      Money(-1234567, uzs), // negative
      Money(150050, usd), // fractional 2-decimal
      Money(-1234, usd), // negative fractional
      Money(0, uzs), // zero
    ];
    for (final m in samples) {
      expect(
        Money.tryParse(m.formatNumber(), m.currency),
        m,
        reason: 'round-trip failed for ${m.format()}',
      );
      expect(
        m.formatNumber().contains(m.currency.symbol),
        isFalse,
        reason: 'formatNumber must not contain the currency symbol',
      );
    }
  });
}
