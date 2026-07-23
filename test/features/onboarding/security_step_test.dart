import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/meta/meta_repository.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:financial_assistant/features/onboarding/onboarding_controller.dart';
import 'package:financial_assistant/features/onboarding/onboarding_screen.dart';
import 'package:financial_assistant/features/onboarding/steps/security_step.dart';
import 'package:financial_assistant/features/security/app_lock_controller.dart';
import 'package:financial_assistant/providers/app_providers.dart';

class _FakeSecretStore implements SecretStore {
  final _m = <String, String>{};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
}

void main() {
  test('the trimmed onboarding is exactly welcome then the security step', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ids = container
        .read(onboardingStepsProvider)
        .map((s) => s.id)
        .toList();
    expect(ids, ['welcome', 'security']);
  });

  testWidgets(
      'setting a PIN in the step flips the draft appLockEnabled and shows a '
      'confirmed badge', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final controller = OnboardingController(
      settingsRepo: DriftSettingsRepository(db),
      metaRepo: DriftMetaRepository(db),
      stepCount: 7,
    );
    final lock = AppLockController(_FakeSecretStore());

    await tester.pumpWidget(ProviderScope(
      overrides: [appLockControllerProvider.overrideWithValue(lock)],
      child: MaterialApp(
        home: Scaffold(
          // A `Builder` defers grabbing the BuildContext until this widget
          // actually builds inside the pumped tree -- calling
          // `tester.element(find.byType(Scaffold))` directly here would
          // evaluate eagerly, before `pumpWidget` mounts anything, and throw
          // "Bad state: No element".
          body: SingleChildScrollView(
            child: Builder(
              builder: (context) => SecurityStep().build(context, controller),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding_security_set_pin')));
    await tester.pumpAndSettle();
    for (final d in '1234'.split('')) {
      await tester.tap(find.byKey(Key('pin_setup_key_$d')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    for (final d in '1234'.split('')) {
      await tester.tap(find.byKey(Key('pin_setup_key_$d')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(controller.state.settings.appLockEnabled, isTrue);
    expect(find.text('PIN o\'rnatildi'), findsOneWidget);
  });
}
