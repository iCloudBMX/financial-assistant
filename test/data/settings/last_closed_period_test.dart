import 'package:drift/native.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lastClosedPeriodStart round-trips through the settings repo', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftSettingsRepository(db);
    final base = await repo.read();
    expect(base.lastClosedPeriodStart, isNull);
    await repo.write(base.copyWith(lastClosedPeriodStart: DateTime(2026, 7, 1)));
    final again = await repo.read();
    expect(again.lastClosedPeriodStart, DateTime(2026, 7, 1));
  });
}
