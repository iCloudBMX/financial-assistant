import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';

/// A genuine v2 database: only the SP0+SP1 tables, created with the v2 shape
/// (categories WITHOUT the SP2 columns; no allocation tables). Reopening this
/// file with the real AppDatabase (v3) must run onUpgrade(2, 3).
class _V2AppDatabase extends AppDatabase {
  _V2AppDatabase(super.e);
  @override
  int get schemaVersion => 2;
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          // v2 categories shape: no kind/limit columns. Create the pre-SP2
          // tables via a raw statement so the added columns are truly absent.
          // NOTE: the real, generated physical name for `CategoriesTable` is
          // `categories_table` (drift keeps the class's `Table` suffix when
          // deriving the default snake_case name — see
          // `app_database.g.dart`'s `$CategoriesTableTable.$name`). The raw
          // DDL below must match that or `into(categoriesTable).insert(...)`
          // (which targets `categories_table`) fails with "no such table".
          await m.database.customStatement(
            'CREATE TABLE categories_table (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, icon TEXT NOT NULL DEFAULT \'category\', '
            'is_default INTEGER NOT NULL DEFAULT 0, archived INTEGER NOT NULL DEFAULT 0, '
            'sort_order INTEGER NOT NULL DEFAULT 0);',
          );
          await m.createTable(appSettingsTable);
          await m.createTable(appMetaTable);
          await m.createTable(accountsTable);
          await m.createTable(transactionsTable);
          await m.createTable(recurringIncomePlansTable);
          await into(appSettingsTable)
              .insert(const AppSettingsTableCompanion(id: Value(0)));
          await into(categoriesTable).insert(
            CategoriesTableCompanion.insert(name: 'Oziq-ovqat'),
          );
        },
        beforeOpen: (d) async =>
            customStatement('PRAGMA foreign_keys = ON'),
      );
}

void main() {
  test('schemaVersion is 3', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 3);
    db.close();
  });

  test('fresh v3 open seeds the default allocation template', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dirs = await db.select(db.allocationDirectionsTable).get();
    expect(dirs, isNotEmpty);
    // income_allocations table exists and is queryable
    expect(await db.select(db.incomeAllocationsTable).get(), isEmpty);
    await db.close();
  });

  test('categories carry the SP2 columns with defaults on a fresh open', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final cats = await db.select(db.categoriesTable).get();
    expect(cats.every((c) => c.kind == 'variable'), isTrue);
    expect(cats.every((c) => c.monthlyLimitMinor == null), isTrue);
    await db.close();
  });

  test('real v2 -> v3 onUpgrade adds columns, creates tables, seeds template', () async {
    final tmp = await Directory.systemTemp.createTemp('schema_v3_upgrade');
    final dbPath = '${tmp.path}/app.db';

    final v2db = _V2AppDatabase(NativeDatabase(File(dbPath)));
    await v2db.select(v2db.appMetaTable).get(); // force onCreate
    expect(v2db.schemaVersion, 2);
    await v2db.close();

    final v3db = AppDatabase(NativeDatabase(File(dbPath)));
    // Existing category row survives and gets the default kind.
    final cats = await v3db.select(v3db.categoriesTable).get();
    expect(cats.single.name, 'Oziq-ovqat');
    expect(cats.single.kind, 'variable');
    // New tables now exist; template seeded.
    expect(await v3db.select(v3db.allocationDirectionsTable).get(), isNotEmpty);
    expect(await v3db.select(v3db.incomeAllocationsTable).get(), isEmpty);
    // Settings gained the new columns with defaults.
    final s = await v3db.select(v3db.appSettingsTable).getSingle();
    expect(s.variableBudgetMinor, 0);
    expect(s.safetyBufferMinor, 0);

    await v3db.close();
    await tmp.delete(recursive: true);
  });
}
