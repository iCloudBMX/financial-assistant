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
          // Likewise build app_settings_table in its pre-SP2 (v2) shape via raw
          // DDL: all the SP1 columns with their exact generated defaults but
          // WITHOUT variable_budget_minor / safety_buffer_minor. Using
          // m.createTable(appSettingsTable) would build the CURRENT class,
          // which already carries the two SP2 columns — so onUpgrade's
          // addColumn calls would be skipped and the v2->v3 settings migration
          // path would get no real coverage. Column list + defaults mirror
          // $AppSettingsTableTable in app_database.g.dart exactly.
          await m.database.customStatement(
            'CREATE TABLE app_settings_table ('
            'id INTEGER NOT NULL PRIMARY KEY DEFAULT 0, '
            'name TEXT NOT NULL DEFAULT \'\', '
            'primary_currency TEXT NOT NULL DEFAULT \'UZS\', '
            'date_format TEXT NOT NULL DEFAULT \'dd.MM.yyyy\', '
            'period_start_day INTEGER NOT NULL DEFAULT 1, '
            'week_start_iso INTEGER NOT NULL DEFAULT 1, '
            'daily_limit_method TEXT NOT NULL DEFAULT \'evenSplit\', '
            'min_reserve_minor INTEGER NOT NULL DEFAULT 0, '
            'min_reserve_currency TEXT NOT NULL DEFAULT \'UZS\', '
            'theme_mode TEXT NOT NULL DEFAULT \'system\', '
            'app_lock_enabled INTEGER NOT NULL DEFAULT 0 CHECK ("app_lock_enabled" IN (0, 1)), '
            'biometric_enabled INTEGER NOT NULL DEFAULT 0 CHECK ("biometric_enabled" IN (0, 1)), '
            'savings_rollover_mode TEXT NOT NULL DEFAULT \'askEachTime\', '
            'notification_flags_json TEXT NOT NULL DEFAULT \'{}\');',
          );
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
    expect(db.schemaVersion, 6);
    db.close();
  });

  test('categories carry the SP2 columns with defaults on a fresh open', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final cats = await db.select(db.categoriesTable).get();
    expect(cats.every((c) => c.kind == 'variable'), isTrue);
    expect(cats.every((c) => c.monthlyLimitMinor == null), isTrue);
    await db.close();
  });

  test('real v2 -> v3 onUpgrade adds columns', () async {
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
    // Settings gained the new columns with defaults.
    final s = await v3db.select(v3db.appSettingsTable).getSingle();
    expect(s.variableBudgetMinor, 0);
    expect(s.safetyBufferMinor, 0);

    await v3db.close();
    await tmp.delete(recursive: true);
  });
}
