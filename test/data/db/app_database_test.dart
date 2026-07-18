import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('onCreate seeds one settings row and one meta row', () async {
    final settings = await db.select(db.appSettingsTable).getSingle();
    expect(settings.primaryCurrency, 'UZS');
    expect(settings.periodStartDay, 1);

    final meta = await db.select(db.appMetaTable).getSingle();
    expect(meta.onboardingComplete, isFalse);
    expect(meta.schemaVersion, 1);
  });

  test('foreign keys pragma is enabled after open', () async {
    final row =
        await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.data.values.first, 1);
  });
}
