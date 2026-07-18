import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/transactions/transactions_controller.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  Future<ProviderContainer> seeded() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    final accId = await c.read(accountRepositoryProvider).create(
        name: 'Naqd', type: AccountType.cash, openingBalance: const Money(1000000, uzs), icon: 'w');
    await c.read(ledgerRepositoryProvider).addExpense(
        accountId: accId, amount: const Money(250000, uzs), categoryId: 1, occurredAt: DateTime(2026, 7, 18));
    return c;
  }

  test('history lists the entry; delete removes it', () async {
    final c = await seeded();
    var list = await c.read(transactionsControllerProvider.future);
    expect(list.length, 1);
    await c.read(transactionsControllerProvider.notifier).delete(list.single.id);
    list = await c.read(transactionsControllerProvider.future);
    expect(list, isEmpty);
  });

  test('editAmount changes the stored magnitude', () async {
    final c = await seeded();
    final list = await c.read(transactionsControllerProvider.future);
    final r = await c.read(transactionsControllerProvider.notifier)
        .editAmount(list.single.id, const Money(100000, uzs));
    expect(r.isOk, isTrue);
    final data = await c.read(dashboardProvider.future);
    expect(data.totals[uzs], const Money(900000, uzs)); // 1,000,000 - 100,000
  });
}
