import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/features/reports/category_report_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shareBp is basis points of total spend, rounded', () {
    expect(shareBp(const Money(250000, CurrencyRegistry.uzs),
        const Money(1000000, CurrencyRegistry.uzs)), 2500);
    expect(shareBp(const Money(1, CurrencyRegistry.uzs),
        const Money(0, CurrencyRegistry.uzs)), 0); // no divide-by-zero
  });
}
