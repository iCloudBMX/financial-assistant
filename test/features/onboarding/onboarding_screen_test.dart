import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/meta/meta_repository.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:financial_assistant/features/onboarding/onboarding_screen.dart';
import 'package:financial_assistant/features/shell/routes.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/ui/components/velora_money_field.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  testWidgets('onboarding renders the welcome step first', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: OnboardingScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Minimal zaxira'), findsNothing); // not on first page
    expect(find.byType(TextField), findsWidgets); // welcome name field present
  });

  testWidgets(
      "every step is skippable: tapping O'tkazib yuborish through the "
      'whole flow with no input reaches Yakunlash and finishes without '
      'creating an account', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final router = buildRouter(onboardingComplete: false);
    addTearDown(router.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    // Skip: welcome -> currency -> period -> account -> financial-baseline.
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(const Key('onboarding_skip_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding_skip_button')));
      await tester.pumpAndSettle();
    }

    // The last step (appearance) has no skip button, only Yakunlash.
    expect(find.byKey(const Key('onboarding_skip_button')), findsNothing);
    expect(find.text('Yakunlash'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();

    final meta = await DriftMetaRepository(db).read();
    expect(meta.onboardingComplete, isTrue);

    final accounts = await container.read(accountRepositoryProvider).list();
    expect(accounts, isEmpty,
        reason: 'skipping the account step must not create an account');
  });

  testWidgets(
      'the account step creates an account through the shared accounts '
      'path when "Hisob qo\'shish" is tapped, and it shows up in the '
      'accounts repository', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: OnboardingScreen()),
    ));
    await tester.pumpAndSettle();

    // Navigate to the account step: welcome -> currency -> period -> account.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('onboarding_skip_button')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Birinchi hisobingiz'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('onboarding_account_name')),
      'Naqd pul',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding_account_balance')),
      '500000',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding_account_create_button')));
    await tester.pumpAndSettle();

    // The created badge replaces the create button.
    expect(find.byKey(const Key('onboarding_account_created_badge')),
        findsOneWidget);

    final accounts = await container.read(accountRepositoryProvider).list();
    expect(accounts, hasLength(1));
    expect(accounts.single.name, 'Naqd pul');
    expect(accounts.single.openingBalance, const Money(500000, uzs));
  });

  testWidgets(
      'creating an account, then navigating back and forward to the account '
      'step, does NOT create a duplicate (the created state survives the '
      'step remount)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: OnboardingScreen()),
    ));
    await tester.pumpAndSettle();

    // Navigate to the account step: welcome -> currency -> period -> account.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('onboarding_skip_button')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Birinchi hisobingiz'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_account_create_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding_account_created_badge')),
        findsOneWidget);
    expect(await container.read(accountRepositoryProvider).list(),
        hasLength(1));

    // Back to the period step, then forward to the account step again --
    // OnboardingScreen keys each step by step.id, so this REMOUNTS a fresh
    // AccountStep widget. If "already created" lived in that widget's local
    // state it would reset here.
    await tester.tap(find.byKey(const Key('onboarding_back_button')));
    await tester.pumpAndSettle();
    expect(find.text('Birinchi hisobingiz'), findsNothing);
    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();
    expect(find.text('Birinchi hisobingiz'), findsOneWidget);

    // The remounted step must reflect that an account already exists: the
    // badge is shown and the create button is gone, so there is no way to
    // (and it does not) create a duplicate.
    expect(find.byKey(const Key('onboarding_account_created_badge')),
        findsOneWidget);
    expect(find.byKey(const Key('onboarding_account_create_button')),
        findsNothing);
    expect(await container.read(accountRepositoryProvider).list(),
        hasLength(1),
        reason: 'no duplicate account after back/forward navigation');
  });

  testWidgets(
      'the financial-baseline step writes the variable budget and minimal '
      'reserve into the committed settings', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final router = buildRouter(onboardingComplete: false);
    addTearDown(router.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    // Navigate to financial-baseline: welcome -> currency -> period ->
    // account -> financial-baseline.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('onboarding_skip_button')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Moliyaviy asos'), findsOneWidget);
    expect(find.byType(VeloraMoneyField), findsNWidgets(2));

    await tester.enterText(
      find.byKey(const Key('onboarding_variable_budget')),
      '3000000',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding_min_reserve')),
      '1000000',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();
    // Finish onboarding from the last (appearance) step.
    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();

    final settings = await DriftSettingsRepository(db).read();
    expect(settings.variableBudget, const Money(3000000, uzs));
    expect(settings.minReserve, const Money(1000000, uzs));
  });
}
