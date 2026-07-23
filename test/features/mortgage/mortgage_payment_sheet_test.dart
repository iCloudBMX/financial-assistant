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
import 'package:financial_assistant/features/accounts/accounts_controller.dart';
import 'package:financial_assistant/features/mortgage/mortgage_payment_sheet.dart';
import 'package:financial_assistant/ui/components/account_card_picker.dart';
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
      'entering principal and interest saves the split; total is their sum',
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

    // Two explicit portions, no total field, no Auto/Manual toggle, plus a
    // card picker for the source account.
    expect(find.text('Qaysi kartadan?'), findsOneWidget);
    expect(find.byType(AccountCardPicker), findsOneWidget);
    expect(find.text('Asosiy qarzga (tani)'), findsOneWidget);
    expect(find.text('Foiz to‘lovi'), findsOneWidget);

    await t.enterText(find.byKey(const Key('payment-principal')), '3500000');
    await t.enterText(find.byKey(const Key('payment-interest')), '1500000');
    await t.pumpAndSettle();

    // Derived total is shown as 3.5M + 1.5M = 5M.
    expect(find.textContaining('5 000 000'), findsWidgets);

    expect(
        t.widget<FilledButton>(find.byKey(const Key('payment-save'))).onPressed,
        isNotNull);

    await t.tap(find.byKey(const Key('payment-save')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('payment-save')), findsNothing); // popped
    final payments =
        await container.read(mortgageRepositoryProvider).payments(id);
    expect(payments.single.principalPortionMinor, 3500000);
    expect(payments.single.interestPortionMinor, 1500000);
    expect(payments.single.totalMinor, 5000000);

    // The payment was drawn from the (auto-selected) card: 500M - 5M = 495M.
    final accounts = await container.read(accountsControllerProvider.future);
    expect(accounts.single.balance.minorUnits, 495000000);
  });

  testWidgets('interest-only payment saves with zero principal', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container =
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final id = await openMortgage(t, container);
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);
    await container.read(mortgagesProvider.future);

    await openSheet(t, container, id);

    await t.enterText(find.byKey(const Key('payment-interest')), '1500000');
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('payment-save')));
    await t.pumpAndSettle();

    final payments =
        await container.read(mortgageRepositoryProvider).payments(id);
    expect(payments.single.principalPortionMinor, 0);
    expect(payments.single.interestPortionMinor, 1500000);
  });

  testWidgets('a payment exceeding the card balance is blocked', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container =
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final id = await openMortgage(t, container); // Karta balance = 500,000,000
    container.read(ledgerRevisionProvider.notifier).update((n) => n + 1);
    await container.read(mortgagesProvider.future);

    await openSheet(t, container, id);

    // Total 600M > 500M on the card.
    await t.enterText(find.byKey(const Key('payment-principal')), '600000000');
    await t.pumpAndSettle();

    expect(find.text('Kartada yetarli mablag\' yo\'q'), findsOneWidget);
    expect(
        t.widget<FilledButton>(find.byKey(const Key('payment-save'))).onPressed,
        isNull);

    // Back within balance -> save re-enables.
    await t.enterText(find.byKey(const Key('payment-principal')), '400000000');
    await t.pumpAndSettle();
    expect(
        t.widget<FilledButton>(find.byKey(const Key('payment-save'))).onPressed,
        isNotNull);
  });

  testWidgets('save stays disabled until at least one portion is entered',
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

    // Nothing typed → save disabled.
    expect(
        t.widget<FilledButton>(find.byKey(const Key('payment-save'))).onPressed,
        isNull);

    await t.enterText(find.byKey(const Key('payment-principal')), '3000000');
    await t.pumpAndSettle();

    expect(
        t.widget<FilledButton>(find.byKey(const Key('payment-save'))).onPressed,
        isNotNull);
  });
}
