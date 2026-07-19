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
import 'package:financial_assistant/features/mortgage/mortgage_extra_payment_sheet.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  testWidgets('recording an extra payment lowers the balance and closes',
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
              onPressed: () => showMortgageExtraPaymentSheet(ctx, ref, id),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('extra-amount')), '2000000');
    await t.pumpAndSettle(); // preview recomputes
    await t.tap(find.byKey(const Key('extra-save')));
    await t.pumpAndSettle();

    expect(
        await container
            .read(mortgageRepositoryProvider)
            .currentPrincipalMinor(id),
        100000000 - 2000000);
  });

  testWidgets(
      'differential preview uses the fixed principal (not a full-term collapse)',
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
    // Term Jan→Nov 2026 = 10 months, opening 1,000,000 => fixed principal
    // ~100,000/mo, so the baseline term is ~10 months.
    final id = await container.read(mortgageRepositoryProvider).create(
        MortgageDraft(
            name: 'Uy',
            initialLoanMinor: 12000000,
            openingPrincipalMinor: 1000000,
            annualRateBp: 1200,
            startDate: DateTime(2026, 1, 1),
            endDate: DateTime(2026, 11, 1),
            mandatoryPaymentMinor: 100000,
            nextPaymentDate: DateTime(2026, 7, 10),
            paymentType: PaymentType.differential));

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(
          builder: (ctx, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showMortgageExtraPaymentSheet(ctx, ref, id),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    // A modest extra (200,000) shortens a ~10-month, 100,000/mo term by 2
    // months. The old bug (omitting monthlyPrincipalMinor) collapsed the
    // differential "after" projection to neverCloses/0-months and reported
    // the ENTIRE remaining term as saved (10 oy). This asserts the true 2.
    await t.enterText(find.byKey(const Key('extra-amount')), '200000');
    await t.pumpAndSettle();

    expect(
        find.textContaining('Muddat qisqarishi: 2 oy'), findsOneWidget);
    expect(find.textContaining('Muddat qisqarishi: 10 oy'), findsNothing);
  });
}
