import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/settings/settings_model.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:financial_assistant/features/settings/settings_controller.dart';
import 'package:financial_assistant/providers/app_providers.dart';

class _FailingWriteRepo implements SettingsRepository {
  final SettingsRepository inner;
  _FailingWriteRepo(this.inner);
  @override
  Future<AppSettings> read() => inner.read();
  @override
  Future<void> write(AppSettings s) async => throw Exception('disk full');
}

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

    // Prove it was durably written, not just held in controller state:
    final persisted = await DriftSettingsRepository(db).read();
    expect(persisted.name, 'Sarvar');
  });

  test('save failure surfaces AsyncError, not a permanent spinner', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      settingsRepositoryProvider.overrideWithValue(
          _FailingWriteRepo(DriftSettingsRepository(db))),
    ]);
    addTearDown(container.dispose);

    final current = await container.read(settingsControllerProvider.future);
    await container
        .read(settingsControllerProvider.notifier)
        .save(current.copyWith(name: 'X'));
    final state = container.read(settingsControllerProvider);
    expect(state, isA<AsyncError<AppSettings>>());
  });
}
