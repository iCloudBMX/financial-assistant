import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/ledger/balance_engine.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/accounts/account_repository.dart';
import 'package:financial_assistant/data/ledger/ledger_repository.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accounts;
  late LedgerRepository ledger;
  const uzs = CurrencyRegistry.uzs;
  final when = DateTime(2026, 7, 18, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    accounts = DriftAccountRepository(db);
    ledger = DriftLedgerRepository(db, accounts);
  });
  tearDown(() => db.close());

  Future<int> newAccount({int opening = 0}) => accounts.create(
      name: 'A', type: AccountType.cash,
      openingBalance: Money(opening, uzs), icon: 'w');

  Future<Money> balanceOf(int id) async =>
      accountBalance((await accounts.byId(id))!, await ledger.entriesForAccount(id));

  test('expense is stored negative and lowers the balance', () async {
    final a = await newAccount(opening: 1000000);
    await ledger.addExpense(accountId: a, amount: const Money(250000, uzs), categoryId: 1, occurredAt: when);
    expect(await balanceOf(a), const Money(750000, uzs));
    final es = await ledger.entriesForAccount(a);
    expect(es.single.amount, const Money(-250000, uzs));
    expect(es.single.type, LedgerEntryType.expense);
  });

  test('income is stored positive with allocated 0', () async {
    final a = await newAccount();
    await ledger.addIncome(accountId: a, amount: const Money(5000000, uzs), incomeType: IncomeType.salary, occurredAt: when);
    final e = (await ledger.entriesForAccount(a)).single;
    expect(e.amount, const Money(5000000, uzs));
    expect(e.allocated, const Money(0, uzs));
    expect(e.incomeType, IncomeType.salary);
  });

  test('transfer writes a linked pair and preserves the total', () async {
    final a = await newAccount(opening: 1000000);
    final b = await newAccount();
    final r = await ledger.transfer(fromId: a, toId: b, amount: const Money(300000, uzs), occurredAt: when);
    expect(r.isOk, isTrue);
    expect(await balanceOf(a), const Money(700000, uzs));
    expect(await balanceOf(b), const Money(300000, uzs));
    final legs = await ledger.allEntries();
    expect(legs.length, 2);
    expect(legs[0].transferId, isNotNull);
    expect(legs[0].transferId, legs[1].transferId);
  });

  test('cross-currency transfer is rejected and writes nothing', () async {
    final a = await newAccount(opening: 1000000); // UZS
    final b = await accounts.create(name: 'USD', type: AccountType.bankCard, openingBalance: const Money(0, CurrencyRegistry.usd), icon: 'c');
    final r = await ledger.transfer(fromId: a, toId: b, amount: const Money(300000, uzs), occurredAt: when);
    expect(r.isOk, isFalse);
    expect(await ledger.allEntries(), isEmpty);
  });

  test('adjustBalance records the delta so the balance equals the real value', () async {
    final a = await newAccount(opening: 1000000);
    await ledger.adjustBalance(accountId: a, realBalance: const Money(950000, uzs), occurredAt: when);
    expect(await balanceOf(a), const Money(950000, uzs));
    final e = (await ledger.entriesForAccount(a)).single;
    expect(e.type, LedgerEntryType.adjustment);
    expect(e.amount, const Money(-50000, uzs));
  });

  test('deleting a transfer leg removes both legs', () async {
    final a = await newAccount(opening: 1000000);
    final b = await newAccount();
    await ledger.transfer(fromId: a, toId: b, amount: const Money(300000, uzs), occurredAt: when);
    final legs = await ledger.allEntries();
    await ledger.deleteEntry(legs.first.id);
    expect(await ledger.allEntries(), isEmpty);
  });

  test('editing an expense recomputes the balance', () async {
    final a = await newAccount(opening: 1000000);
    final id = await ledger.addExpense(accountId: a, amount: const Money(250000, uzs), categoryId: 1, occurredAt: when);
    final r = await ledger.editEntry(id: id, amount: const Money(100000, uzs));
    expect(r.isOk, isTrue);
    expect(await balanceOf(a), const Money(900000, uzs));
  });

  test('editing a transfer leg is rejected', () async {
    final a = await newAccount(opening: 1000000);
    final b = await newAccount();
    await ledger.transfer(fromId: a, toId: b, amount: const Money(300000, uzs), occurredAt: when);
    final leg = (await ledger.allEntries()).first;
    final r = await ledger.editEntry(id: leg.id, amount: const Money(1, uzs));
    expect(r.isOk, isFalse);
  });

  test('editing an entry with a different currency is rejected and leaves it unchanged', () async {
    final a = await newAccount(opening: 1000000);
    final id = await ledger.addExpense(accountId: a, amount: const Money(250000, uzs), categoryId: 1, occurredAt: when);
    final r = await ledger.editEntry(id: id, amount: const Money(5000, CurrencyRegistry.usd));
    expect(r.isOk, isFalse);
    final e = (await ledger.entriesForAccount(a)).single;
    expect(e.amount, const Money(-250000, uzs));
  });
}
