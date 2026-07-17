import 'package:drift/native.dart';
import 'package:financial_assistant/app.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/meta/meta_repository.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'a returning user with app-lock enabled never sees the shell, '
      'even transiently, while settings is still loading', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final settingsRepo = DriftSettingsRepository(db);
    final s = await settingsRepo.read();
    await settingsRepo.write(s.copyWith(appLockEnabled: true));
    await DriftMetaRepository(db).markOnboardingComplete();

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const App(),
    ));
    await tester.pumpAndSettle();

    // Locked: the lock screen is shown, and the 5-tab shell is never
    // reachable behind it -- this proves the wired steady-state gates the
    // router render on the *persisted* appLockEnabled setting rather than
    // ever rendering the shell with a defaulted-to-false value while
    // settings was still loading.
    expect(find.text('Ilova qulflangan'), findsOneWidget);
    expect(find.byKey(const Key('app_lock_pin_field')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
