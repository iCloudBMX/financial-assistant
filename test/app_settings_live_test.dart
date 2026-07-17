import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/app.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/meta/meta_repository.dart';
import 'package:financial_assistant/features/settings/settings_controller.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  testWidgets('enabling app-lock in-session locks without a restart',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await DriftMetaRepository(db).markOnboardingComplete(); // returning user
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const App(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget); // shell reachable, unlocked

    // Enable app-lock through the same controller the Settings screen uses.
    final current = await container.read(settingsControllerProvider.future);
    await container
        .read(settingsControllerProvider.notifier)
        .save(current.copyWith(appLockEnabled: true));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing); // now locked, no restart
  });
}
