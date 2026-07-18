import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/allocation/allocation_models.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/allocation/allocation_repository.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  late AppDatabase db;
  late DriftAllocationRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftAllocationRepository(db);
    // Migrations turn on `PRAGMA foreign_keys`, so transactions_table's
    // accountId FK must resolve — seed the account row insertIncome() below
    // points at (mirrors the pattern in schema_v2_migration_test.dart).
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(name: 'Cash', type: 'cash'),
        );
  });
  tearDown(() => db.close());

  Future<int> insertIncome(int minor) => db.into(db.transactionsTable).insert(
        TransactionsTableCompanion.insert(
          accountId: 1,
          type: 'income',
          amountMinor: minor,
          currencyCode: 'UZS',
          occurredAt: DateTime(2026, 7, 5),
          createdAt: DateTime(2026, 7, 5),
        ),
      );

  test('the seeded default template reads back in order', () async {
    final t = await repo.template();
    expect(t.directions.map((d) => d.bucketKey).toList(),
        ['minReserve', 'variableBudget']);
    expect(t.directions.first.method, AllocationMethod.percentage);
    expect(t.directions.first.percentBp, 1000);
    expect(t.directions.last.method, AllocationMethod.remaining);
  });

  test('saveTemplate replaces all directions and re-numbers sortOrder', () async {
    await repo.saveTemplate([
      AllocationDirection(
          bucketKey: 'mandatoryExpenses',
          method: AllocationMethod.fixedAmount,
          amount: const Money(400000, uzs)),
      AllocationDirection(
          bucketKey: 'variableBudget', method: AllocationMethod.remaining),
    ]);
    final t = await repo.template();
    expect(t.directions.map((d) => d.bucketKey).toList(),
        ['mandatoryExpenses', 'variableBudget']);
    expect(t.directions.first.amount, const Money(400000, uzs));
  });

  test('allocateIncome writes the split and updates allocatedMinor', () async {
    final incomeId = await insertIncome(1000000);
    await repo.allocateIncome(incomeId, {
      'minReserve': const Money(100000, uzs),
      'variableBudget': const Money(500000, uzs),
    });
    final row = await (db.select(db.transactionsTable)
          ..where((t) => t.id.equals(incomeId)))
        .getSingle();
    expect(row.allocatedMinor, 600000);
    final reserved = await repo.reservedTotals(uzs);
    expect(reserved['minReserve'], const Money(100000, uzs));
    expect(reserved['variableBudget'], const Money(500000, uzs));
  });

  test('re-allocating an income replaces its previous split', () async {
    final incomeId = await insertIncome(1000000);
    await repo.allocateIncome(incomeId, {'minReserve': const Money(100000, uzs)});
    await repo.allocateIncome(incomeId, {'minReserve': const Money(250000, uzs)});
    final reserved = await repo.reservedTotals(uzs);
    expect(reserved['minReserve'], const Money(250000, uzs));
    final row = await (db.select(db.transactionsTable)
          ..where((t) => t.id.equals(incomeId)))
        .getSingle();
    expect(row.allocatedMinor, 250000);
  });
}
