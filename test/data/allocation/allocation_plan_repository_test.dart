import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/allocation/allocation_plan.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/accounts/account_repository.dart';
import 'package:financial_assistant/data/allocation/allocation_plan_repository.dart';
import 'package:financial_assistant/data/db/app_database.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => Money(v, uzs);

  late AppDatabase db;
  late AccountRepository accounts;
  late AllocationPlanRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    accounts = DriftAccountRepository(db);
    repo = DriftAllocationPlanRepository(db, accounts);
  });
  tearDown(() => db.close());

  Future<int> makeAccount(String name, {int opening = 0, String role = 'spending'}) {
    return db.into(db.accountsTable).insert(AccountsTableCompanion.insert(
          name: name,
          type: 'bankCard',
          openingBalanceMinor: Value(opening),
          role: Value(role),
        ));
  }

  test('plan() is empty by default (no source, no rules)', () async {
    final p = await repo.plan();
    expect(p.sourceAccountId, isNull);
    expect(p.rules, isEmpty);
  });

  test('setSource + saveRules round-trip in sortOrder', () async {
    final src = await makeAccount('Sarf', opening: 3000000);
    final dst1 = await makeAccount('Kredit', role: 'credit');
    final dst2 = await makeAccount('Jamgarma', role: 'savings');
    await repo.setSource(src);
    await repo.saveRules([
      AllocationRule(destinationAccountId: dst1, amount: m(500000), sortOrder: 0),
      AllocationRule(destinationAccountId: dst2, amount: m(300000), sortOrder: 1),
    ]);
    final p = await repo.plan();
    expect(p.sourceAccountId, src);
    expect(p.rules.map((r) => r.destinationAccountId), [dst1, dst2]);
    expect(p.rules[0].amount, m(500000));
    expect(p.rules[1].amount, m(300000));
  });

  test('applyPlan moves money atomically and records transfers, not spends', () async {
    final src = await makeAccount('Sarf', opening: 2000000);
    final dst1 = await makeAccount('Kredit', role: 'credit');
    final dst2 = await makeAccount('Jamgarma', role: 'savings');
    final result = await repo.applyPlan(src, [
      PlannedTransfer(dst1, m(500000)),
      PlannedTransfer(dst2, m(300000)),
    ]);
    expect(result.isOk, isTrue);

    // Balances after: source 1.2M, dst1 500k, dst2 300k — computed from the
    // raw ledger rows (opening balance + summed signed entries).
    final entries = await db.select(db.transactionsTable).get();
    int balance(int accId, int opening) =>
        opening + entries.where((e) => e.accountId == accId)
            .fold(0, (s, e) => s + e.amountMinor);
    expect(balance(src, 2000000), 1200000);
    expect(balance(dst1, 0), 500000);
    expect(balance(dst2, 0), 300000);
    // Transfers are transferOut/transferIn, never expense/income.
    expect(entries.every((e) => e.type == 'transferOut' || e.type == 'transferIn'), isTrue);
    // Each transfer pair shares a transferId; two transfers -> 4 rows, 2 ids.
    expect(entries.length, 4);
    expect(entries.map((e) => e.transferId).toSet().length, 2);
  });

  test('applyPlan with a missing destination fails and writes nothing', () async {
    final src = await makeAccount('Sarf', opening: 2000000);
    final result = await repo.applyPlan(src, [
      PlannedTransfer(999999, m(500000)), // no such account
    ]);
    expect(result.isOk, isFalse);
    final entries = await db.select(db.transactionsTable).get();
    expect(entries, isEmpty); // atomic: nothing persisted
  });
}
