import 'package:drift/drift.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../db/app_database.dart';
import 'settings_model.dart';

abstract class SettingsRepository {
  Future<AppSettings> read();
  Future<void> write(AppSettings settings);
}

class DriftSettingsRepository implements SettingsRepository {
  final AppDatabase db;
  DriftSettingsRepository(this.db);

  @override
  Future<AppSettings> read() async {
    final row = await db.select(db.appSettingsTable).getSingle();
    return AppSettings(
      name: row.name,
      primaryCurrency: CurrencyRegistry.byCode(row.primaryCurrency),
      dateFormat: row.dateFormat,
      periodStartDay: row.periodStartDay,
      weekStartIso: row.weekStartIso,
      dailyLimitMethod: DailyLimitMethod.values.byName(row.dailyLimitMethod),
      minReserve: Money(
        row.minReserveMinor,
        CurrencyRegistry.byCode(row.minReserveCurrency),
      ),
      themeMode: ThemeModeSetting.values.byName(row.themeMode),
      appLockEnabled: row.appLockEnabled,
      biometricEnabled: row.biometricEnabled,
      savingsRolloverMode: SavingsRolloverMode.values.byName(
        row.savingsRolloverMode,
      ),
      variableBudget: Money(
        row.variableBudgetMinor,
        CurrencyRegistry.byCode(row.primaryCurrency),
      ),
      safetyBuffer: Money(
        row.safetyBufferMinor,
        CurrencyRegistry.byCode(row.primaryCurrency),
      ),
      allocationSourceAccountId: row.allocationSourceAccountId,
      lastClosedPeriodStart: row.lastClosedPeriodStart,
    );
  }

  @override
  Future<void> write(AppSettings s) async {
    await (db.update(db.appSettingsTable)..where((t) => t.id.equals(0))).write(
      AppSettingsTableCompanion(
        id: const Value(0),
        name: Value(s.name),
        primaryCurrency: Value(s.primaryCurrency.code),
        dateFormat: Value(s.dateFormat),
        periodStartDay: Value(s.periodStartDay),
        weekStartIso: Value(s.weekStartIso),
        dailyLimitMethod: Value(s.dailyLimitMethod.name),
        minReserveMinor: Value(s.minReserve.minorUnits),
        minReserveCurrency: Value(s.minReserve.currency.code),
        themeMode: Value(s.themeMode.name),
        appLockEnabled: Value(s.appLockEnabled),
        biometricEnabled: Value(s.biometricEnabled),
        savingsRolloverMode: Value(s.savingsRolloverMode.name),
        variableBudgetMinor: Value(s.variableBudget.minorUnits),
        safetyBufferMinor: Value(s.safetyBuffer.minorUnits),
        allocationSourceAccountId: Value(s.allocationSourceAccountId),
        lastClosedPeriodStart: Value(s.lastClosedPeriodStart),
      ),
    );
  }
}
