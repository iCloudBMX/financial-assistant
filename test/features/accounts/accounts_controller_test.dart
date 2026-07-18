import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/accounts/accounts_controller.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  ProviderContainer makeContainer(AppDatabase db) {
    final c = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    addTearDown(db.close);
    return c;
  }

  test('createAccount shows up with its opening balance', () async {
    final c = makeContainer(AppDatabase(NativeDatabase.memory()));
    await c.read(accountsControllerProvider.notifier).createAccount(
        name: 'Naqd', type: AccountType.cash,
        openingBalance: const Money(500000, uzs), icon: 'wallet');
    final list = await c.read(accountsControllerProvider.future);
    expect(list.single.account.name, 'Naqd');
    expect(list.single.balance, const Money(500000, uzs));
  });

  test('archived accounts drop out of the list', () async {
    final c = makeContainer(AppDatabase(NativeDatabase.memory()));
    final ctrl = c.read(accountsControllerProvider.notifier);
    await ctrl.createAccount(name: 'A', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');
    var list = await c.read(accountsControllerProvider.future);
    await ctrl.archive(list.single.account.id);
    list = await c.read(accountsControllerProvider.future);
    expect(list, isEmpty);
  });
}
