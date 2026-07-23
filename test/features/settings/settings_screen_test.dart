import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:financial_assistant/features/security/app_lock_controller.dart';
import 'package:financial_assistant/features/settings/settings_controller.dart';
import 'package:financial_assistant/features/settings/settings_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';

class _FakeSecretStore implements SecretStore {
  final _m = <String, String>{};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
}

void main() {
  const uzs = CurrencyRegistry.uzs;

  testWidgets(
      'opening the min-reserve editor and pressing Saqlash unedited keeps '
      'the reserve (no silent drop)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // Seed a non-zero minReserve directly via the repository before the
    // controller ever reads it.
    final repo = DriftSettingsRepository(db);
    final initial = await repo.read();
    await repo.write(initial.copyWith(minReserve: const Money(500000, uzs)));

    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    // Sanity: the list tile shows the formatted (symbol-bearing) value.
    expect(find.text('500 000 so\u2018m'), findsOneWidget);

    // Open the "Minimal zaxira" editor. The new "Kategoriyalar" row above it
    // in the financial-preferences group pushes it below the default test
    // viewport's fold, so it must be scrolled into view first.
    await tester.ensureVisible(find.text('Minimal zaxira'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minimal zaxira'));
    await tester.pumpAndSettle();

    // The dialog field must be seeded with the parseable numeric form
    // (no currency symbol), so it round-trips through Money.tryParse.
    expect(find.text('500 000'), findsOneWidget);

    // Press Saqlash WITHOUT editing the field.
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    // The reserve must be preserved, not silently dropped.
    final after = await container.read(settingsControllerProvider.future);
    expect(after.minReserve, const Money(500000, uzs));

    final persisted = await repo.read();
    expect(persisted.minReserve, const Money(500000, uzs));
  });

  testWidgets(
      'Settings is grouped into the design-spec sections (profile, '
      'financial preferences, notifications, appearance, privacy & '
      'security, data management), top to bottom', (tester) async {
    // Tall surface so every grouped section renders without needing to
    // scroll to find its header (ListView virtualizes offscreen children).
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    const sectionsInOrder = [
      'Profil',
      'Moliyaviy sozlamalar',
      'Bildirishnomalar',
      "Ko'rinish",
      'Maxfiylik va xavfsizlik',
      "Ma'lumotlar",
    ];

    for (final section in sectionsInOrder) {
      expect(find.text(section), findsOneWidget,
          reason: 'missing Settings section header: $section');
    }

    final positions = [
      for (final section in sectionsInOrder)
        tester.getTopLeft(find.text(section)).dy,
    ];
    for (var i = 1; i < positions.length; i++) {
      expect(positions[i], greaterThan(positions[i - 1]),
          reason: 'Settings sections must appear in the design-spec order');
    }

    // Financial-preference and privacy/security controls still live under
    // their grouped headers.
    expect(find.text('Valyuta'), findsOneWidget);
    expect(find.text('Ilova qulfi'), findsOneWidget);
    expect(find.text('Biometrik autentifikatsiya'), findsOneWidget);
  });

  testWidgets(
      'enabling App Lock runs PIN setup and persists appLockEnabled=true',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final lock = AppLockController(_FakeSecretStore());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      appLockControllerProvider.overrideWithValue(lock),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ilova qulfi'));
    await tester.tap(find.text('Ilova qulfi'));
    await tester.pumpAndSettle();

    // PIN setup sheet is open; enter + confirm.
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

    final settings = await container.read(settingsControllerProvider.future);
    expect(settings.appLockEnabled, isTrue);
    expect(await lock.verifyPin('1234'), isTrue);
  });

  testWidgets(
      'cancelling PIN setup leaves App Lock off and stores no PIN',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final lock = AppLockController(_FakeSecretStore());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      appLockControllerProvider.overrideWithValue(lock),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ilova qulfi'));
    await tester.tap(find.text('Ilova qulfi'));
    await tester.pumpAndSettle();

    // Dismiss the sheet without entering a PIN (tap the barrier).
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    final settings = await container.read(settingsControllerProvider.future);
    expect(settings.appLockEnabled, isFalse);
    expect(await lock.verifyPin('1234'), isFalse);
  });

  testWidgets(
      "Ma'lumotlar section shows enabled export/restore tiles (no placeholder)",
      (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Zaxira nusxa yaratish'));
    expect(find.text('Zaxira nusxa yaratish'), findsOneWidget);
    expect(find.text('Zaxiradan tiklash'), findsOneWidget);
    expect(find.text("Ma'lumotlarni eksport qilish"), findsNothing);

    final exportTile = tester.widget<ListTile>(find.ancestor(
      of: find.text('Zaxira nusxa yaratish'),
      matching: find.byType(ListTile),
    ));
    expect(exportTile.enabled, isTrue);
  });

  testWidgets('Biometric switch is disabled while App Lock is off',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      appLockControllerProvider
          .overrideWithValue(AppLockController(_FakeSecretStore())),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    final biometric = tester.widget<SwitchListTile>(find.ancestor(
      of: find.text('Biometrik autentifikatsiya'),
      matching: find.byType(SwitchListTile),
    ));
    expect(biometric.onChanged, isNull); // disabled
  });
}
