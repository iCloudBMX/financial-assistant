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

  ProviderContainer makeContainer() {
    final db = AppDatabase(NativeDatabase.memory());
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    addTearDown(db.close);
    return c;
  }

  Future<int> add(ProviderContainer c, String name, int opening) => c
      .read(accountsControllerProvider.notifier)
      .createAccount(name: name, type: AccountType.cash, openingBalance: Money(opening, uzs), icon: 'w')
      .then((_) async {
    final list = await c.read(accountsControllerProvider.future);
    return list.firstWhere((e) => e.account.name == name).account.id;
  });

  test('transfer moves balance between accounts', () async {
    final c = makeContainer();
    final a = await add(c, 'A', 1000000);
    final b = await add(c, 'B', 0);
    final r = await c.read(accountsControllerProvider.notifier)
        .transfer(fromId: a, toId: b, amount: const Money(300000, uzs));
    expect(r.isOk, isTrue);
    final list = await c.read(accountsControllerProvider.future);
    Money bal(String n) => list.firstWhere((e) => e.account.name == n).balance;
    expect(bal('A'), const Money(700000, uzs));
    expect(bal('B'), const Money(300000, uzs));
  });

  test('adjust makes the balance equal the real value', () async {
    final c = makeContainer();
    final a = await add(c, 'A', 1000000);
    await c.read(accountsControllerProvider.notifier)
        .adjust(accountId: a, realBalance: const Money(950000, uzs));
    final list = await c.read(accountsControllerProvider.future);
    expect(list.single.balance, const Money(950000, uzs));
  });
}
