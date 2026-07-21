import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/transactions/transaction_filter.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/transactions/transactions_filter_provider.dart';
import 'package:financial_assistant/features/transactions/transactions_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';

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

  const uzs = CurrencyRegistry.uzs;

  testWidgets('type filter narrows the list and updates the summary',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      // start all-time so both seeded rows are visible regardless of run date
      transactionFilterProvider.overrideWith((ref) => const TransactionFilter()),
    ]);
    addTearDown(container.dispose);
    final accId = await container.read(accountRepositoryProvider).create(
        name: 'Naqd',
        type: AccountType.cash,
        openingBalance: const Money(1000000, uzs),
        icon: 'w');
    await container.read(ledgerRepositoryProvider).addExpense(
        accountId: accId,
        amount: const Money(250000, uzs),
        categoryId: 1,
        occurredAt: DateTime(2026, 7, 18));
    await container.read(ledgerRepositoryProvider).addIncome(
        accountId: accId,
        amount: const Money(500000, uzs),
        incomeType: IncomeType.salary,
        occurredAt: DateTime(2026, 7, 18));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TransactionsScreen()),
    ));
    await tester.pumpAndSettle();

    // Both rows visible initially.
    expect(find.text('Oziq-ovqat'), findsOneWidget);
    expect(find.text('Maosh'), findsOneWidget);

    // Apply an expense-only filter directly through the provider.
    container.read(transactionFilterProvider.notifier).state =
        const TransactionFilter(types: {LedgerEntryType.expense});
    await tester.pumpAndSettle();

    expect(find.text('Oziq-ovqat'), findsOneWidget);
    expect(find.text('Maosh'), findsNothing);
  });

  testWidgets('tapping the Davr chip opens the period sheet', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      transactionFilterProvider.overrideWith((ref) => const TransactionFilter()),
    ]);
    addTearDown(container.dispose);
    final accId = await container.read(accountRepositoryProvider).create(
        name: 'Naqd',
        type: AccountType.cash,
        openingBalance: const Money(1000000, uzs),
        icon: 'w');
    // The filter chips row only renders once the ledger has entries (the
    // `all.isEmpty` guard shows the empty state otherwise), so seed one.
    await container.read(ledgerRepositoryProvider).addExpense(
        accountId: accId,
        amount: const Money(250000, uzs),
        categoryId: 1,
        occurredAt: DateTime(2026, 7, 18));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TransactionsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('filter-chip-period')));
    await tester.pumpAndSettle();

    // The Davr sheet shows its date-field labels and preset chips.
    expect(find.text('Sanadan'), findsOneWidget);
    expect(find.text("O'tgan hafta"), findsWidgets);
  });
}
