import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';

void main() {
  test('UZS has zero decimal digits and after-position symbol', () {
    final uzs = CurrencyRegistry.uzs;
    expect(uzs.code, 'UZS');
    expect(uzs.symbol, 'so\u2018m');
    expect(uzs.decimalDigits, 0);
    expect(uzs.symbolPosition, SymbolPosition.after);
  });

  test('USD has two decimal digits', () {
    expect(CurrencyRegistry.usd.decimalDigits, 2);
  });

  test('byCode returns the registered currency', () {
    expect(CurrencyRegistry.byCode('UZS'), CurrencyRegistry.uzs);
  });

  test('byCode throws ArgumentError for unknown code', () {
    expect(() => CurrencyRegistry.byCode('XXX'), throwsArgumentError);
  });
}
