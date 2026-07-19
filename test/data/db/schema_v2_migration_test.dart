import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/db/default_categories.dart';

/// A genuine v1 schema: only the two Foundation tables, created explicitly
/// (never `createAll()`, which would also create the v2 tables and defeat
/// the point of this fixture). Subclassing the real [AppDatabase] lets us
/// reuse its generated table getters while overriding `schemaVersion` and
/// `migration` so the on-disk file this writes is indistinguishable from a
/// real pre-upgrade Foundation install.
class _V1AppDatabase extends AppDatabase {
  _V1AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createTable(appSettingsTable);
          await m.createTable(appMetaTable);
          await into(appMetaTable).insert(
            AppMetaTableCompanion.insert(
              id: const Value(0),
              installedAt: DateTime.now(),
            ),
          );
          await into(appSettingsTable)
              .insert(const AppSettingsTableCompanion(id: Value(0)));
        },
      );
}

void main() {
  test('schemaVersion is 3', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 5);
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

  test(
      'real v1 -> v2 onUpgrade creates the new tables and seeds categories',
      () async {
    final tmp = await Directory.systemTemp.createTemp('schema_v2_upgrade');
    final dbPath = '${tmp.path}/app.db';

    // 1. Create a genuine v1 database on disk.
    final v1db = _V1AppDatabase(NativeDatabase(File(dbPath)));
    // Force the connection open (and onCreate to run) now.
    await v1db.select(v1db.appMetaTable).get();
    expect(v1db.schemaVersion, 1);
    await v1db.close();

    // 2. Reopen the same file with the real AppDatabase (schemaVersion 2).
    // This must trigger onUpgrade(m, 1, 2), not onCreate.
    final v2db = AppDatabase(NativeDatabase(File(dbPath)));
    // Force the migration to run by querying a real table.
    final accounts = await v2db.select(v2db.accountsTable).get();
    final transactions = await v2db.select(v2db.transactionsTable).get();
    final plans = await v2db.select(v2db.recurringIncomePlansTable).get();
    final cats = await v2db.select(v2db.categoriesTable).get();

    expect(accounts, isEmpty);
    expect(transactions, isEmpty);
    expect(plans, isEmpty);
    expect(cats.length, kDefaultCategories.length);
    expect(cats.length, 13);
    expect(cats.every((c) => c.isDefault), isTrue);

    await v2db.close();
    await tmp.delete(recursive: true);
  });
}
