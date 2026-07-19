import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';

/// A genuine v3 database: every SP0–SP2 table but NOT the SP3 goals tables.
/// Reopening this file with the real AppDatabase (v4) must run onUpgrade(3, 4)
/// and create goals_table + goal_contributions_table.
class _V3AppDatabase extends AppDatabase {
  _V3AppDatabase(super.e);
  @override
  int get schemaVersion => 3;
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createTable(appSettingsTable);
          await m.createTable(appMetaTable);
          await m.createTable(accountsTable);
          await m.createTable(categoriesTable);
          await m.createTable(transactionsTable);
          await m.createTable(recurringIncomePlansTable);
          await m.createTable(allocationDirectionsTable);
          await m.createTable(incomeAllocationsTable);
          await into(appSettingsTable)
              .insert(const AppSettingsTableCompanion(id: Value(0)));
        },
        beforeOpen: (d) async => customStatement('PRAGMA foreign_keys = ON'),
      );
}

void main() {
  test('schemaVersion is 4', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 4);
    db.close();
  });

  test('fresh v4 open has empty, queryable goal tables', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(await db.select(db.goalsTable).get(), isEmpty);
    expect(await db.select(db.goalContributionsTable).get(), isEmpty);
    await db.close();
  });

  test('real v3 -> v4 onUpgrade creates the goal tables', () async {
    final tmp = await Directory.systemTemp.createTemp('schema_v4_upgrade');
    final dbPath = '${tmp.path}/app.db';

    final v3db = _V3AppDatabase(NativeDatabase(File(dbPath)));
    await v3db.select(v3db.appSettingsTable).get(); // force onCreate
    expect(v3db.schemaVersion, 3);
    await v3db.close();

    final v4db = AppDatabase(NativeDatabase(File(dbPath)));
    // New tables exist and are queryable after the upgrade.
    expect(await v4db.select(v4db.goalsTable).get(), isEmpty);
    expect(await v4db.select(v4db.goalContributionsTable).get(), isEmpty);

    await v4db.close();
    await tmp.delete(recursive: true);
  });
}
