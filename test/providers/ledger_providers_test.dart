import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  test('dashboardProvider reflects a saved expense', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final accounts = container.read(accountRepositoryProvider);
    final ledger = container.read(ledgerRepositoryProvider);
    final id = await accounts.create(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(1000000, CurrencyRegistry.uzs), icon: 'w');
    await ledger.addExpense(
        accountId: id, amount: const Money(250000, CurrencyRegistry.uzs),
        categoryId: 1, occurredAt: DateTime.now());

    final data = await container.read(dashboardProvider.future);
    expect(data.totals[CurrencyRegistry.uzs], const Money(750000, CurrencyRegistry.uzs));
  });
}
