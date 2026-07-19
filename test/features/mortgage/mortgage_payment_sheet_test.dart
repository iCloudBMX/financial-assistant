import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/mortgage/mortgage_engine.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/mortgage/mortgage_model.dart';
import 'package:financial_assistant/features/mortgage/mortgage_payment_sheet.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  Future<int> openMortgage(WidgetTester t, ProviderContainer container) async {
    await container.read(accountRepositoryProvider).create(
        name: 'Karta',
        type: AccountType.bankCard,
        openingBalance: const Money(500000000, CurrencyRegistry.uzs),
        icon: 'account_balance_wallet');
    return container.read(mortgageRepositoryProvider).create(MortgageDraft(
        name: 'Uy',
        initialLoanMinor: 120000000,
        openingPrincipalMinor: 100000000,
        annualRateBp: 1800,
        startDate: DateTime(2025, 1, 1),
        mandatoryPaymentMinor: 5000000,
        nextPaymentDate: DateTime(2026, 7, 10),
        paymentType: PaymentType.annuity));
  }

  Future<void> openSheet(WidgetTester t, ProviderContainer container, int id) async {
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(
          builder: (ctx, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showMortgagePaymentSheet(ctx, ref, id),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  testWidgets(
      'Auto mode derives the split from the plan and enables save with only '
      'the total entered', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container =
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final id = await openMortgage(t, container);
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);
    await container.read(mortgagesProvider.future);

    await openSheet(t, container, id);

    // Auto is the default mode; both split labels are visible even though
    // they're derived, not typed.
    expect(find.text('Asosiy qarzga'), findsOneWidget);
    expect(find.text('Foiz to‘lovi'), findsOneWidget);

    await t.enterText(find.byKey(const Key('payment-total')), '5000000');
    await t.pumpAndSettle();

    // monthlyInterestMinor(100000000, 1800bp) = 1,500,000 -> principal 3,500,000.
    expect(find.textContaining('1 500 000'), findsWidgets);
    expect(find.textContaining('3 500 000'), findsWidgets);

    final button =
        t.widget<FilledButton>(find.byKey(const Key('payment-save')));
    expect(button.onPressed, isNotNull);

    await t.tap(find.byKey(const Key('payment-save')));
    await t.pumpAndSettle();

    final payments =
        await container.read(mortgageRepositoryProvider).payments(id);
    expect(payments.single.principalPortionMinor, 3500000);
    expect(payments.single.interestPortionMinor, 1500000);
  });

  testWidgets(
      'Auto mode disables save when the total exceeds payoff (over-payment '
      'cannot drive the balance negative)', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container =
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final id = await openMortgage(t, container);
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);
    await container.read(mortgagesProvider.future);

    await openSheet(t, container, id);

    // Outstanding is 100,000,000; a 200,000,000 total is a gross over-payoff.
    await t.enterText(find.byKey(const Key('payment-total')), '200000000');
    await t.pumpAndSettle();

    expect(
        t.widget<FilledButton>(find.byKey(const Key('payment-save'))).onPressed,
        isNull);
    expect(find.textContaining('oshib ketdi'), findsOneWidget);
    expect(
        await container.read(mortgageRepositoryProvider).payments(id), isEmpty);
  });

  testWidgets(
      'Manual mode shows both explicit portions and an unbalanced split '
      'disables save', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container =
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final id = await openMortgage(t, container);
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);
    await container.read(mortgagesProvider.future);

    await openSheet(t, container, id);

    await t.tap(find.byKey(const Key('payment-mode-manual')));
    await t.pumpAndSettle();

    expect(find.text('Asosiy qarzga'), findsOneWidget);
    expect(find.text('Foiz to‘lovi'), findsOneWidget);

    await t.enterText(find.byKey(const Key('payment-total')), '5000000');
    await t.enterText(find.byKey(const Key('payment-principal')), '3000000');
    await t.enterText(
        find.byKey(const Key('payment-interest')), '1000000'); // 4M != 5M
    await t.pumpAndSettle();

    expect(
        t.widget<FilledButton>(find.byKey(const Key('payment-save'))).onPressed,
        isNull);

    expect(
        await container.read(mortgageRepositoryProvider).payments(id), isEmpty);
  });

  testWidgets('Manual mode with a balanced split saves and closes the sheet',
      (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container =
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final id = await openMortgage(t, container);
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);
    await container.read(mortgagesProvider.future);

    await openSheet(t, container, id);

    await t.tap(find.byKey(const Key('payment-mode-manual')));
    await t.pumpAndSettle();

    await t.enterText(find.byKey(const Key('payment-total')), '5000000');
    await t.enterText(find.byKey(const Key('payment-principal')), '3500000');
    await t.enterText(find.byKey(const Key('payment-interest')), '1500000');
    await t.pumpAndSettle();

    expect(
        t.widget<FilledButton>(find.byKey(const Key('payment-save'))).onPressed,
        isNotNull);

    await t.tap(find.byKey(const Key('payment-save')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('payment-save')), findsNothing); // popped
    expect(
        (await container.read(mortgageRepositoryProvider).payments(id))
            .length,
        1);
  });

  testWidgets(
      'switching back to Auto after editing Manual fields recomputes the '
      'derived split instead of keeping the stale manual numbers', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container =
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final id = await openMortgage(t, container);
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);
    await container.read(mortgagesProvider.future);

    await openSheet(t, container, id);

    await t.enterText(find.byKey(const Key('payment-total')), '5000000');
    await t.tap(find.byKey(const Key('payment-mode-manual')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('payment-principal')), '1000000');
    await t.enterText(find.byKey(const Key('payment-interest')), '1000000');
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('payment-mode-auto')));
    await t.pumpAndSettle();

    expect(find.textContaining('1 500 000'), findsWidgets);
    expect(find.textContaining('3 500 000'), findsWidgets);
    expect(
        t.widget<FilledButton>(find.byKey(const Key('payment-save'))).onPressed,
        isNotNull);
  });
}
