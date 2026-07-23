import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/db/db_open.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:financial_assistant/data/settings/settings_model.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';

/// A database that pretends to be one version newer and always fails to
/// upgrade — used to exercise the recovery path against a real on-disk file.
class _FailingUpgradeDb extends AppDatabase {
  _FailingUpgradeDb(super.e);
  @override
  int get schemaVersion => 9; // stay ahead of the real version (now 8)
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async => throw Exception('boom'),
        beforeOpen: (d) async =>
            customStatement('PRAGMA foreign_keys = ON'),
      );
}

void main() {
  test('a failed migration restores the snapshot; the user\'s data survives',
      () async {
    final tmp = await Directory.systemTemp.createTemp('mig');
    final dbPath = '${tmp.path}/app.db';

    // 1. Create a real v2 db and store some user data.
    final first = await openAppDatabase(dbPath: dbPath);
    expect(first.isOk, isTrue);
    final db1 = first.valueOrNull!;
    await DriftSettingsRepository(db1).write(
      const AppSettings(
        name: 'Ali',
        primaryCurrency: CurrencyRegistry.uzs,
        dateFormat: 'dd.MM.yyyy',
        periodStartDay: 1,
        weekStartIso: 1,
        dailyLimitMethod: DailyLimitMethod.evenSplit,
        minReserve: Money(0, CurrencyRegistry.uzs),
        themeMode: ThemeModeSetting.system,
        appLockEnabled: false,
        biometricEnabled: false,
        savingsRolloverMode: SavingsRolloverMode.askEachTime,
      ),
    );
    await db1.close();

    // 2. Reopen with a factory whose 2->3 migration throws.
    final failed =
        await openAppDatabase(dbPath: dbPath, open: _FailingUpgradeDb.new);
    expect(failed.isOk, isFalse);

    // 3. Reopen normally: the restored snapshot means data is intact.
    final recovered = await openAppDatabase(dbPath: dbPath);
    expect(recovered.isOk, isTrue);
    final db3 = recovered.valueOrNull!;
    final settings = await DriftSettingsRepository(db3).read();
    expect(settings.name, 'Ali');
    await db3.close();

    await tmp.delete(recursive: true);
  });
}
