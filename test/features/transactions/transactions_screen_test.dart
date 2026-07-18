import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/transactions/transactions_controller.dart';
import 'package:financial_assistant/features/transactions/transactions_screen.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  Future<ProviderContainer> seeded() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    final accId = await c.read(accountRepositoryProvider).create(
        name: 'Naqd',
        type: AccountType.cash,
        openingBalance: const Money(1000000, uzs),
        icon: 'w');
    await c.read(ledgerRepositoryProvider).addExpense(
        accountId: accId,
        amount: const Money(250000, uzs),
        categoryId: 1,
        occurredAt: DateTime(2026, 7, 18));
    return c;
  }

  testWidgets(
      'swiping a row asks for confirmation; canceling keeps the entry',
      (tester) async {
    final container = await seeded();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TransactionsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Chiqim'), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Confirmation dialog appears before anything is deleted.
    expect(find.text('Tranzaksiyani o\'chirish'), findsOneWidget);

    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();

    // Entry is preserved.
    final list = await container.read(transactionsControllerProvider.future);
    expect(list, hasLength(1));
    expect(find.text('Chiqim'), findsOneWidget);
  });

  testWidgets('swiping a row and confirming deletes the entry',
      (tester) async {
    final container = await seeded();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TransactionsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Chiqim'), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tranzaksiyani o\'chirish'), findsOneWidget);

    await tester.tap(find.text('O\'chirish'));
    await tester.pumpAndSettle();

    final list = await container.read(transactionsControllerProvider.future);
    expect(list, isEmpty);
  });
}
