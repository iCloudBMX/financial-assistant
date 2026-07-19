import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:financial_assistant/features/onboarding/onboarding_screen.dart';
import 'package:financial_assistant/features/security/app_lock_controller.dart';
import 'package:financial_assistant/features/security/app_lock_gate.dart';
import 'package:financial_assistant/features/settings/settings_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';

import '../support/golden_devices.dart';
import '../support/velora_test_app.dart';

class _FakeStore implements SecretStore {
  final _m = <String, String>{};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
}

/// Never authenticates on its own in a golden test -- the biometric icon is
/// present (biometricEnabled: true) but this fake always fails, so the
/// captured frame is the resting PIN-entry state, not a transient prompt.
class _NeverBiometricController extends AppLockController {
  _NeverBiometricController() : super(_FakeStore());
  @override
  Future<bool> authenticateBiometric() async => false;
}

Future<ProviderContainer> _onboardingContainerAtAccountStep() async {
  final db = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(() {
    container.dispose();
    db.close();
  });
  // welcome(0) -> currency(1) -> period(2) -> account(3).
  final controller = container.read(onboardingControllerProvider.notifier);
  controller.next();
  controller.next();
  controller.next();
  return container;
}

Future<ProviderContainer> _settingsContainer() async {
  const uzs = CurrencyRegistry.uzs;
  final db = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(() {
    container.dispose();
    db.close();
  });

  final repo = DriftSettingsRepository(db);
  final initial = await repo.read();
  await repo.write(initial.copyWith(
    name: 'Sarvar',
    minReserve: const Money(500000, uzs),
  ));
  return container;
}

void main() {
  testWidgets(
      "Onboarding's account step (progressive/skippable flow) matches the "
      'approved layout at 390px light', (tester) async {
    final container = await _onboardingContainerAtAccountStep();

    await pumpVelora(
      tester,
      child: UncontrolledProviderScope(
        container: container,
        child: const OnboardingScreen(),
      ),
      size: phone390,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('baselines/onboarding-account-light-390.png'),
    );
  });

  testWidgets('Onboarding reflows without overflow at 320px dark 200% scale',
      (tester) async {
    final container = await _onboardingContainerAtAccountStep();

    await pumpVelora(
      tester,
      child: UncontrolledProviderScope(
        container: container,
        child: const OnboardingScreen(),
      ),
      size: phone320,
      brightness: Brightness.dark,
      textScale: textScale200,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('baselines/onboarding-account-dark-320-scale200.png'),
    );
  });

  testWidgets(
      'Settings matches the grouped-sections layout at 390px light',
      (tester) async {
    final container = await _settingsContainer();

    await pumpVelora(
      tester,
      child: UncontrolledProviderScope(
        container: container,
        child: const SettingsScreen(),
      ),
      size: phone390,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('baselines/settings-grouped-light-390.png'),
    );
  });

  testWidgets('Settings reflows without overflow at 320px dark 200% scale',
      (tester) async {
    final container = await _settingsContainer();

    await pumpVelora(
      tester,
      child: UncontrolledProviderScope(
        container: container,
        child: const SettingsScreen(),
      ),
      size: phone320,
      brightness: Brightness.dark,
      textScale: textScale200,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('baselines/settings-grouped-dark-320-scale200.png'),
    );
  });

  testWidgets(
      'App Lock PIN keypad (biometric retry icon shown) matches the '
      'approved layout at 390px light', (tester) async {
    final controller = _NeverBiometricController();
    await controller.setPin('1234');

    await pumpVelora(
      tester,
      child: AppLockGate(
        controller: controller,
        enabled: true,
        biometricEnabled: true,
        child: const Scaffold(body: Text('Unlocked home')),
      ),
      size: phone390,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(AppLockGate),
      matchesGoldenFile('baselines/app-lock-keypad-light-390.png'),
    );
  });

  testWidgets(
      'App Lock PIN keypad reflows without overflow at 320px dark 200% '
      'scale', (tester) async {
    final controller = _NeverBiometricController();
    await controller.setPin('1234');

    await pumpVelora(
      tester,
      child: AppLockGate(
        controller: controller,
        enabled: true,
        biometricEnabled: true,
        child: const Scaffold(body: Text('Unlocked home')),
      ),
      size: phone320,
      brightness: Brightness.dark,
      textScale: textScale200,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(AppLockGate),
      matchesGoldenFile('baselines/app-lock-keypad-dark-320-scale200.png'),
    );
  });
}
