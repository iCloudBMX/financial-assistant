import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/allocation/allocation_controller.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  test('preview splits income by the seeded default template', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final result = await container
        .read(allocationControllerProvider)
        .preview(const Money(1000000, uzs));
    // default template: 10% minReserve, remainder variableBudget
    expect(result.perBucket['minReserve'], const Money(100000, uzs));
    expect(result.perBucket['variableBudget'], const Money(900000, uzs));
    expect(result.undistributed, const Money(0, uzs));
  });

  test('confirm writes the split and bumps the revision', () async {
    final db = AppDatabase(NativeDatabase.memory());
    // Migrations turn on `PRAGMA foreign_keys`, so transactions_table's
    // accountId FK must resolve — seed the account row it points at (mirrors
    // the pattern in allocation_repository_test.dart).
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(name: 'Cash', type: 'cash'),
        );
    final incomeId = await db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: 1,
            type: 'income',
            amountMinor: 1000000,
            currencyCode: 'UZS',
            occurredAt: DateTime(2026, 7, 5),
            createdAt: DateTime(2026, 7, 5),
          ),
        );
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final before = container.read(ledgerRevisionProvider);
    await container.read(allocationControllerProvider).confirm(incomeId, {
      'minReserve': const Money(100000, uzs),
      'variableBudget': const Money(900000, uzs),
    });
    expect(container.read(ledgerRevisionProvider), greaterThan(before));
    final row = await (db.select(db.transactionsTable)
          ..where((t) => t.id.equals(incomeId)))
        .getSingle();
    expect(row.allocatedMinor, 1000000);
  });
}
