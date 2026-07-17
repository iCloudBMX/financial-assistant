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
}
