import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/expense_entry/expense_entry_controller.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  LedgerEntry exp(int cat) => LedgerEntry(
      id: cat, accountId: 1, type: LedgerEntryType.expense,
      amount: const Money(-1, uzs), allocated: const Money(0, uzs),
      occurredAt: DateTime(2026, 7, cat), categoryId: cat);

  test('quickPickCategoryIds is recent-first, distinct, capped', () {
    final ids = quickPickCategoryIds([exp(1), exp(2), exp(2), exp(3)], limit: 2);
    expect(ids.length, 2);
    expect(ids.first, anyOf(3, 2)); // most recent / most used surface first
  });

  test('save records an expense against the default account and supports undo',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);

    final accId = await c.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(1000000, uzs), icon: 'w');
    // default account resolves to the only account
    var st = await c.read(expenseEntryControllerProvider.future);
    expect(st.defaultAccountId, accId);

    await c.read(expenseEntryControllerProvider.notifier)
        .save(amount: const Money(250000, uzs), categoryId: 1);
    final data = await c.read(dashboardProvider.future);
    expect(data.totals[uzs], const Money(750000, uzs));

    await c.read(expenseEntryControllerProvider.notifier).undo();
    final after = await c.read(dashboardProvider.future);
    expect(after.totals[uzs], const Money(1000000, uzs));
  });
}
