import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/settings/settings_model.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftSettingsRepository(db);
  });
  tearDown(() => db.close());

  test('default row reads back UZS defaults', () async {
    final s = await repo.read();
    expect(s.primaryCurrency, CurrencyRegistry.uzs);
    expect(s.periodStartDay, 1);
    expect(s.appLockEnabled, isFalse);
  });

  test('write then read round-trips every field', () async {
    final updated = (await repo.read()).copyWith(
      name: 'Sarvar',
      periodStartDay: 5,
      minReserve: const Money(2000000, CurrencyRegistry.uzs),
      themeMode: ThemeModeSetting.dark,
      appLockEnabled: true,
    );
    await repo.write(updated);
    final s = await repo.read();
    expect(s.name, 'Sarvar');
    expect(s.periodStartDay, 5);
    expect(s.minReserve, const Money(2000000, CurrencyRegistry.uzs));
    expect(s.themeMode, ThemeModeSetting.dark);
    expect(s.appLockEnabled, isTrue);
  });

  test('write then read round-trips all 11 fields', () async {
    final updated = (await repo.read()).copyWith(
      name: 'Sarvar',
      primaryCurrency: CurrencyRegistry.usd,
      dateFormat: 'yyyy-MM-dd',
      periodStartDay: 5,
      weekStartIso: 7,
      dailyLimitMethod: DailyLimitMethod.fixedDaily,
      minReserve: const Money(2000000, CurrencyRegistry.uzs),
      themeMode: ThemeModeSetting.dark,
      appLockEnabled: true,
      biometricEnabled: true,
      savingsRolloverMode: SavingsRolloverMode.rolloverDays,
    );
    await repo.write(updated);
    final s = await repo.read();
    expect(s.name, 'Sarvar');
    expect(s.primaryCurrency, CurrencyRegistry.usd);
    expect(s.dateFormat, 'yyyy-MM-dd');
    expect(s.periodStartDay, 5);
    expect(s.weekStartIso, 7);
    expect(s.dailyLimitMethod, DailyLimitMethod.fixedDaily);
    expect(s.minReserve, const Money(2000000, CurrencyRegistry.uzs));
    expect(s.themeMode, ThemeModeSetting.dark);
    expect(s.appLockEnabled, isTrue);
    expect(s.biometricEnabled, isTrue);
    expect(s.savingsRolloverMode, SavingsRolloverMode.rolloverDays);
  });

  test('variable budget and safety buffer round-trip', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = DriftSettingsRepository(db);
    final base = await repo.read();
    await repo.write(base.copyWith(
      variableBudget: const Money(1400000, CurrencyRegistry.uzs),
      safetyBuffer: const Money(50000, CurrencyRegistry.uzs),
    ));
    final back = await repo.read();
    expect(back.variableBudget, const Money(1400000, CurrencyRegistry.uzs));
    expect(back.safetyBuffer, const Money(50000, CurrencyRegistry.uzs));
    await db.close();
  });

  test('write() preserves the untracked notificationFlagsJson column', () async {
    // Seed a non-default value directly in the DB, then perform a normal write().
    await (db.update(db.appSettingsTable)..where((t) => t.id.equals(0))).write(
      const AppSettingsTableCompanion(
        notificationFlagsJson: Value('{"budget":true}'),
      ),
    );
    await repo.write((await repo.read()).copyWith(name: 'Sarvar'));
    final row = await db.select(db.appSettingsTable).getSingle();
    expect(row.notificationFlagsJson, '{"budget":true}'); // not reset to '{}'
  });
}
