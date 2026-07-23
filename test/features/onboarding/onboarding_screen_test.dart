import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/meta/meta_repository.dart';
import 'package:financial_assistant/features/onboarding/onboarding_screen.dart';
import 'package:financial_assistant/features/shell/routes.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
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
      'the trimmed flow is welcome -> security: skipping welcome reaches the '
      'last (security) step and Yakunlash completes onboarding without '
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

    // Welcome (step 1 of 2) is skippable.
    expect(find.byKey(const Key('onboarding_skip_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_skip_button')));
    await tester.pumpAndSettle();

    // Security is the last step: no skip, only Yakunlash.
    expect(find.byKey(const Key('onboarding_skip_button')), findsNothing);
    expect(find.text('Yakunlash'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();

    final meta = await DriftMetaRepository(db).read();
    expect(meta.onboardingComplete, isTrue);

    final accounts = await container.read(accountRepositoryProvider).list();
    expect(accounts, isEmpty,
        reason: 'the trimmed flow no longer creates an account');
  });
}
