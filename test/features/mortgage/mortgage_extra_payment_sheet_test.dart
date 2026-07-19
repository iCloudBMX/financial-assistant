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
}
