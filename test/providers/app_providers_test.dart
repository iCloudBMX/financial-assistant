import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  test('settingsProvider reads defaults through the overridden database',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final settings = await container.read(settingsProvider.future);
    expect(settings.primaryCurrency, CurrencyRegistry.uzs);
  });
}
