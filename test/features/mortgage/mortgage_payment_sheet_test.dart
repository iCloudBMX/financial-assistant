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
  testWidgets('an unbalanced split shows an error and keeps the sheet open',
      (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await container.read(accountRepositoryProvider).create(
        name: 'Karta',
        type: AccountType.bankCard,
        openingBalance: const Money(500000000, CurrencyRegistry.uzs),
        icon: 'account_balance_wallet');
    final id = await container.read(mortgageRepositoryProvider).create(
        MortgageDraft(
            name: 'Uy',
            initialLoanMinor: 120000000,
            openingPrincipalMinor: 100000000,
            annualRateBp: 1800,
            startDate: DateTime(2025, 1, 1),
            mandatoryPaymentMinor: 5000000,
            nextPaymentDate: DateTime(2026, 7, 10),
            paymentType: PaymentType.annuity));

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

    await t.enterText(find.byKey(const Key('payment-total')), '5000000');
    await t.enterText(find.byKey(const Key('payment-principal')), '3000000');
    await t.enterText(
        find.byKey(const Key('payment-interest')), '1000000'); // 4M != 5M
    await t.tap(find.byKey(const Key('payment-save')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('payment-save')), findsOneWidget); // still open
    expect(
        await container.read(mortgageRepositoryProvider).payments(id), isEmpty);
  });

  testWidgets('a balanced split records and closes the sheet', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await container.read(accountRepositoryProvider).create(
        name: 'Karta',
        type: AccountType.bankCard,
        openingBalance: const Money(500000000, CurrencyRegistry.uzs),
        icon: 'account_balance_wallet');
    final id = await container.read(mortgageRepositoryProvider).create(
        MortgageDraft(
            name: 'Uy',
            initialLoanMinor: 120000000,
            openingPrincipalMinor: 100000000,
            annualRateBp: 1800,
            startDate: DateTime(2025, 1, 1),
            mandatoryPaymentMinor: 5000000,
            nextPaymentDate: DateTime(2026, 7, 10),
            paymentType: PaymentType.annuity));

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

    await t.enterText(find.byKey(const Key('payment-total')), '5000000');
    await t.enterText(find.byKey(const Key('payment-principal')), '3500000');
    await t.enterText(find.byKey(const Key('payment-interest')), '1500000');
    await t.tap(find.byKey(const Key('payment-save')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('payment-save')), findsNothing); // popped
    expect(
        (await container.read(mortgageRepositoryProvider).payments(id))
            .length,
        1);
  });
}
