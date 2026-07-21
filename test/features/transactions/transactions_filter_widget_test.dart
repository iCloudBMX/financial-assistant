import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:financial_assistant/core/transactions/transaction_filter.dart';
import 'package:financial_assistant/features/transactions/transactions_filter_provider.dart';

void main() {
  test('filter defaults to the current month', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final f = c.read(transactionFilterProvider);
    expect(f.periodLabel, 'Bu oy');
    expect(f.period, isNotNull);
  });

  test('overriding the filter to all-time widens it', () {
    final c = ProviderContainer(overrides: [
      transactionFilterProvider.overrideWith((ref) => const TransactionFilter()),
    ]);
    addTearDown(c.dispose);
    expect(c.read(transactionFilterProvider).period, isNull);
  });
}
