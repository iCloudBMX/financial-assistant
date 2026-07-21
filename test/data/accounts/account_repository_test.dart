// test/data/accounts/account_repository_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/accounts/account_repository.dart';

void main() {
  late AppDatabase db;
  late AccountRepository repo;
  const uzs = CurrencyRegistry.uzs;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftAccountRepository(db);
  });
  tearDown(() => db.close());

  test('create then read back a domain Account', () async {
    final id = await repo.create(
        name: 'Naqd',
        type: AccountType.cash,
        openingBalance: const Money(500000, uzs),
        icon: 'wallet');
    final a = await repo.byId(id);
    expect(a, isNotNull);
    expect(a!.name, 'Naqd');
    expect(a.type, AccountType.cash);
    expect(a.openingBalance, const Money(500000, uzs));
    expect(a.currency, uzs);
    expect(a.archived, isFalse);
  });

  test('list hides archived unless asked', () async {
    final a = await repo.create(
        name: 'A', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');
    await repo.create(
        name: 'B', type: AccountType.bankCard, openingBalance: const Money(0, uzs), icon: 'c');
    await repo.setArchived(a, true);
    expect((await repo.list()).length, 1);
    expect((await repo.list(includeArchived: true)).length, 2);
  });

  test('reorder assigns sortOrder in the given order', () async {
    final a = await repo.create(name: 'A', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');
    final b = await repo.create(name: 'B', type: AccountType.cash, openingBalance: const Money(0, uzs), icon: 'w');
    await repo.reorder([b, a]);
    final names = (await repo.list()).map((e) => e.name).toList();
    expect(names, ['B', 'A']);
  });

  test('create defaults role to spending; round-trips role', () async {
    final id = await repo.create(
        name: 'Naqd',
        type: AccountType.cash,
        openingBalance: const Money(0, uzs),
        icon: 'wallet');
    expect((await repo.byId(id))!.role, AccountRole.spending);

    final id2 = await repo.create(
        name: 'Zaxira',
        type: AccountType.bankCard,
        openingBalance: const Money(0, uzs),
        icon: 'wallet',
        role: AccountRole.reserve);
    expect((await repo.byId(id2))!.role, AccountRole.reserve);
  });

  test('setRole updates the stored role', () async {
    final id = await repo.create(
        name: 'A',
        type: AccountType.cash,
        openingBalance: const Money(0, uzs),
        icon: 'w');
    await repo.setRole(id, AccountRole.credit);
    expect((await repo.byId(id))!.role, AccountRole.credit);
    // list() reads role too
    expect((await repo.list()).single.role, AccountRole.credit);
  });
}
