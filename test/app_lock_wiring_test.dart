import 'package:drift/native.dart';
import 'package:financial_assistant/app.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/meta/meta_repository.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:financial_assistant/features/security/app_lock_controller.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStore implements SecretStore {
  final _m = <String, String>{};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
}

void main() {
  testWidgets('appLockEnabled=true shows the lock screen, not a crash',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final metaRepo = DriftMetaRepository(db);
    await metaRepo.markOnboardingComplete();
    final settingsRepo = DriftSettingsRepository(db);
    final s = await settingsRepo.read();
    await settingsRepo.write(s.copyWith(appLockEnabled: true));

    final store = _FakeStore();
    final controller = AppLockController(store);
    await controller.setPin('1234');

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appLockControllerProvider.overrideWithValue(controller),
      ],
      child: const App(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ilova qulflangan'), findsOneWidget);
    expect(find.byKey(const Key('app_lock_pin_field')), findsOneWidget);
    // The 5-tab shell must not be visible behind the lock.
    expect(find.byType(NavigationBar), findsNothing);

    await tester.enterText(
        find.byKey(const Key('app_lock_pin_field')), '1234');
    await tester.tap(find.byKey(const Key('app_lock_unlock_button')));
    await tester.pumpAndSettle();

    // Correct PIN unlocks into the 5-tab shell.
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
