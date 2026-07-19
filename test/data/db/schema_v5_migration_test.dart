import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';

/// A genuine v4 database: every SP0–SP3 table but NOT the SP4 mortgage tables.
/// Reopening this file with the real AppDatabase (v5) must run onUpgrade(4, 5)
/// and create mortgages_table + mortgage_payments_table.
class _V4AppDatabase extends AppDatabase {
  _V4AppDatabase(super.e);
  @override
  int get schemaVersion => 4;
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
          await m.createTable(goalsTable);
          await m.createTable(goalContributionsTable);
          await into(appSettingsTable)
              .insert(const AppSettingsTableCompanion(id: Value(0)));
        },
        beforeOpen: (d) async => customStatement('PRAGMA foreign_keys = ON'),
      );
}

void main() {
  test('schemaVersion is 5', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 5);
    db.close();
  });

  test('fresh v5 open has empty, queryable mortgage tables', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(await db.select(db.mortgagesTable).get(), isEmpty);
    expect(await db.select(db.mortgagePaymentsTable).get(), isEmpty);
    await db.close();
  });

  test('real v4 -> v5 onUpgrade creates the mortgage tables', () async {
    final tmp = await Directory.systemTemp.createTemp('schema_v5_upgrade');
    final dbPath = '${tmp.path}/app.db';

    final v4db = _V4AppDatabase(NativeDatabase(File(dbPath)));
    await v4db.select(v4db.appSettingsTable).get(); // force onCreate
    expect(v4db.schemaVersion, 4);
    await v4db.close();

    final v5db = AppDatabase(NativeDatabase(File(dbPath)));
    expect(await v5db.select(v5db.mortgagesTable).get(), isEmpty);
    expect(await v5db.select(v5db.mortgagePaymentsTable).get(), isEmpty);

    await v5db.close();
    await tmp.delete(recursive: true);
  });
}
