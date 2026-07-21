import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/onboarding/onboarding_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  testWidgets(
      'the onboarding account step shows the four role chips, defaulting '
      'to spending, and passes the selected role to createAccount',
      (tester) async {
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

    for (final r in ['spending', 'reserve', 'credit', 'savings']) {
      expect(find.byKey(Key('onboarding-account-role-$r')), findsOneWidget);
    }
    expect(find.text('Sarf'), findsOneWidget);

    // Selecting a different role updates the chip selection and the account
    // created afterwards carries that role.
    await tester.ensureVisible(
      find.byKey(const Key('onboarding-account-role-reserve')),
    );
    await tester.tap(find.byKey(const Key('onboarding-account-role-reserve')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('onboarding_account_create_button')),
    );
    await tester
        .tap(find.byKey(const Key('onboarding_account_create_button')));
    await tester.pumpAndSettle();

    final accounts = await container.read(accountRepositoryProvider).list();
    expect(accounts, hasLength(1));
    expect(accounts.single.role, AccountRole.reserve);

    // Once created, the role chips disable like the type chips do.
    final chip = tester.widget<ChoiceChip>(
      find.byKey(const Key('onboarding-account-role-spending')),
    );
    expect(chip.onSelected, isNull);
  });
}
