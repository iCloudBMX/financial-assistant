import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';

/// A genuine v5 database: accounts_table built WITHOUT the SP-A `role`
/// column (raw DDL, so onUpgrade's addColumn path gets real coverage —
/// m.createTable(accountsTable) would build today's shape which already
/// carries `role`). All other SP0–SP5 tables are current-shape.
class _V5AppDatabase extends AppDatabase {
  _V5AppDatabase(super.e);
  @override
  int get schemaVersion => 5;
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          // Pre-SP-A accounts_table: no `role`. Column list + defaults
          // mirror $AccountsTableTable in app_database.g.dart exactly,
          // minus role. created_at is stored as INTEGER (unix seconds).
          await m.database.customStatement(
            'CREATE TABLE accounts_table ('
            'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, '
            'type TEXT NOT NULL, '
            'opening_balance_minor INTEGER NOT NULL DEFAULT 0, '
            'currency_code TEXT NOT NULL DEFAULT \'UZS\', '
            'icon TEXT NOT NULL DEFAULT \'wallet\', '
            'archived INTEGER NOT NULL DEFAULT 0 CHECK ("archived" IN (0, 1)), '
            'sort_order INTEGER NOT NULL DEFAULT 0, '
            'created_at INTEGER NOT NULL);',
          );
          await m.createTable(appSettingsTable);
          await m.createTable(appMetaTable);
          await m.createTable(categoriesTable);
          await m.createTable(transactionsTable);
          await m.createTable(recurringIncomePlansTable);
          await m.createTable(goalsTable);
          await m.createTable(goalContributionsTable);
          await m.createTable(mortgagesTable);
          await m.createTable(mortgagePaymentsTable);
          await into(appSettingsTable)
              .insert(const AppSettingsTableCompanion(id: Value(0)));
          // Seed two accounts via raw insert (no role column exists yet).
          await m.database.customStatement(
            "INSERT INTO accounts_table (name, type, created_at) "
            "VALUES ('Jamg''arma kartasi', 'savings', 0)");
          await m.database.customStatement(
            "INSERT INTO accounts_table (name, type, created_at) "
            "VALUES ('Naqd', 'cash', 0)");
        },
        beforeOpen: (d) async => customStatement('PRAGMA foreign_keys = ON'),
      );
}

void main() {
  test('schemaVersion is 7', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 7);
    db.close();
  });

  test('fresh v6 open: accounts default to spending role', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(name: 'X', type: 'cash'),
        );
    final rows = await db.select(db.accountsTable).get();
    expect(rows.single.role, 'spending');
    await db.close();
  });

  test('real v5 -> v6 onUpgrade adds role + applies default mapping', () async {
    final tmp = await Directory.systemTemp.createTemp('schema_v6_upgrade');
    final dbPath = '${tmp.path}/app.db';

    final v5db = _V5AppDatabase(NativeDatabase(File(dbPath)));
    await v5db.select(v5db.appSettingsTable).get(); // force onCreate
    expect(v5db.schemaVersion, 5);
    await v5db.close();

    final v6db = AppDatabase(NativeDatabase(File(dbPath)));
    final rows = await v6db.select(v6db.accountsTable).get();
    final byName = {for (final r in rows) r.name: r.role};
    // savings type -> savings role; everything else -> spending.
    expect(byName['Jamg\'arma kartasi'], 'savings');
    expect(byName['Naqd'], 'spending');

    await v6db.close();
    await tmp.delete(recursive: true);
  });
}
