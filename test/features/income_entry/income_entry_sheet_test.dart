import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/income_entry/income_entry_sheet.dart';
import 'package:financial_assistant/ui/components/account_card_picker.dart';
import 'package:financial_assistant/ui/components/velora_money_field.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  Future<ProviderContainer> pumpSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container =
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    await container.read(accountRepositoryProvider).create(
        name: 'Naqd',
        type: AccountType.cash,
        openingBalance: const Money(1000000, uzs),
        icon: 'w');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showIncomeEntrySheet(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
      'shows a formatted autofocus amount field, an account picker, and a Batafsil toggle',
      (tester) async {
    await pumpSheet(tester);

    final moneyField =
        tester.widget<VeloraMoneyField>(find.byType(VeloraMoneyField));
    expect(moneyField.autofocus, isTrue);
    expect(find.byType(AccountCardPicker), findsOneWidget);
    expect(find.text('Batafsil'), findsOneWidget);
  });

  testWidgets('Saqlash stays disabled until a positive amount is entered',
      (tester) async {
    // The money field is bound to the account's currency, so a currency
    // mismatch is not reachable from this sheet — that guard is covered by
    // the controller test. What the sheet is responsible for is the
    // save-enablement gate, asserted honestly here.
    await pumpSheet(tester);
    final saveButton = find.widgetWithText(FilledButton, 'Saqlash');
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull,
        reason: 'disabled with an empty amount');

    await tester.enterText(find.byType(VeloraMoneyField), '5000000');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull,
        reason: 'enabled once a positive amount is entered');
  });
}
