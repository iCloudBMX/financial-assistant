import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/settings/settings_controller.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  test('save persists and updates the controller state', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    final current =
        await container.read(settingsControllerProvider.future);
    await container
        .read(settingsControllerProvider.notifier)
        .save(current.copyWith(name: 'Sarvar'));

    final after = await container.read(settingsControllerProvider.future);
    expect(after.name, 'Sarvar');
  });
}
