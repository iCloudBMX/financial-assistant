import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/expense_entry/expense_entry_sheet.dart';
import 'package:financial_assistant/features/transactions/transactions_controller.dart';
import 'package:financial_assistant/ui/components/account_card_picker.dart';
import 'package:financial_assistant/ui/components/velora_money_field.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  Future<ProviderContainer> pumpSheet(WidgetTester tester) async {
    // Tall surface so the whole sheet (amount, account picker, category
    // picker, and the collapsed Batafsil toggle) fits without needing to
    // scroll to hit-test controls near the bottom.
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
                onPressed: () => showExpenseEntrySheet(context, ref),
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
      'shows a formatted autofocus amount field, an account picker, four quick categories, and a Batafsil toggle',
      (tester) async {
    await pumpSheet(tester);

    final moneyField = tester.widget<VeloraMoneyField>(
      find.byType(VeloraMoneyField),
    );
    expect(moneyField.autofocus, isTrue);

    expect(find.byType(AccountCardPicker), findsOneWidget);
    expect(find.byKey(const Key('quick-category')), findsNWidgets(4));
    expect(find.text('Batafsil'), findsOneWidget);
  });

  testWidgets('preselects the last-used active account', (tester) async {
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
    final cardId = await container.read(accountRepositoryProvider).create(
        name: 'Karta',
        type: AccountType.bankCard,
        openingBalance: const Money(2000000, uzs),
        icon: 'c');
    // Most recent entry is against the card account.
    await container.read(ledgerRepositoryProvider).addExpense(
        accountId: cardId,
        amount: const Money(50000, uzs),
        categoryId: 1,
        occurredAt: DateTime(2026, 7, 18));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showExpenseEntrySheet(context, ref),
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

    final picker =
        tester.widget<AccountCardPicker>(find.byType(AccountCardPicker));
    expect(picker.selectedId, cardId);
  });

  testWidgets('the searchable full selector filters by name and returns a selection',
      (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.byKey(const Key('category-picker-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category-sheet')), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'Transport');
    await tester.pumpAndSettle();
    // Transport is category id 2 (second seeded default category).
    expect(find.byKey(const Key('category-option-2')), findsOneWidget);
    expect(find.byKey(const Key('category-option-5')), findsNothing); // Sog'liq

    await tester.tap(find.byKey(const Key('category-option-2')));
    await tester.pumpAndSettle();
    // The category sheet closes and returns to the amount flow.
    expect(find.byKey(const Key('category-sheet')), findsNothing);
  });

  testWidgets('Batafsil is collapsed by default and reveals the note field when opened',
      (tester) async {
    await pumpSheet(tester);

    expect(find.byKey(const Key('expense-note-field')), findsNothing);

    await tester.tap(find.text('Batafsil'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('expense-note-field')), findsOneWidget);
  });

  testWidgets('saving offers Bekor qilish, and tapping it undoes the save',
      (tester) async {
    final container = await pumpSheet(tester);

    await tester.enterText(find.byType(VeloraMoneyField), '150000');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-category')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saqlash'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Chiqim saqlandi'), findsOneWidget);
    expect(find.text('Bekor qilish'), findsOneWidget);

    var list = await container.read(transactionsControllerProvider.future);
    expect(list, hasLength(1));

    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();

    list = await container.read(transactionsControllerProvider.future);
    expect(list, isEmpty);
  });
}
