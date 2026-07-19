// test/core/budget/category_budget_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/budget/category_budget_engine.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => const Money(0, uzs).add(Money(v, uzs));

  test('null limit is noLimit regardless of spend', () {
    expect(categoryStatus(m(999999), null), CategoryLimitStatus.noLimit);
  });

  test('spent below 85% of the limit is safe', () {
    expect(categoryStatus(m(84999), m(100000)), CategoryLimitStatus.safe);
  });

  test('spent at exactly 85% is near', () {
    expect(categoryStatus(m(85000), m(100000)), CategoryLimitStatus.near);
  });

  test('spent equal to the limit is near, not over', () {
    expect(categoryStatus(m(100000), m(100000)), CategoryLimitStatus.near);
  });

  test('spent above the limit is over', () {
    expect(categoryStatus(m(100001), m(100000)), CategoryLimitStatus.over);
  });

  test('remaining and deviation are signed opposites', () {
    expect(categoryRemaining(m(30000), m(100000)), m(70000));
    expect(categoryDeviation(m(130000), m(100000)), m(30000));
    expect(categoryDeviation(m(30000), m(100000)), const Money(-70000, uzs));
  });
}
