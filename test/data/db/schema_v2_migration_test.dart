import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/db/default_categories.dart';

void main() {
  test('schemaVersion is 2', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 2);
    db.close();
  });

  test('fresh open seeds the 13 default categories and creates all tables',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final cats = await db.select(db.categoriesTable).get();
    expect(cats.length, kDefaultCategories.length);
    expect(cats.length, 13);
    expect(cats.every((c) => c.isDefault), isTrue);

    // All four new tables are queryable (no exception thrown).
    expect(await db.select(db.accountsTable).get(), isEmpty);
    expect(await db.select(db.transactionsTable).get(), isEmpty);
    expect(await db.select(db.recurringIncomePlansTable).get(), isEmpty);
    await db.close();
  });

  test('an account row inserts and reads back', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final id = await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Naqd',
            type: 'cash',
            openingBalanceMinor: const Value(500000),
            currencyCode: const Value('UZS'),
            icon: const Value('wallet'),
          ),
        );
    final row = await (db.select(db.accountsTable)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    expect(row.name, 'Naqd');
    expect(row.openingBalanceMinor, 500000);
    await db.close();
  });
}
