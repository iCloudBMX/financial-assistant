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
import 'package:financial_assistant/core/transactions/transaction_filter.dart';
import 'package:financial_assistant/features/transactions/transactions_filter_provider.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  Future<ProviderContainer> seeded() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      transactionFilterProvider.overrideWith((ref) => const TransactionFilter()),
    ]);
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
    expect(find.text('Oziq-ovqat'), findsOneWidget);

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
    expect(find.text('Oziq-ovqat'), findsOneWidget);
  });

  testWidgets('swiping a row and confirming deletes the entry',
      (tester) async {
    final container = await seeded();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TransactionsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Oziq-ovqat'), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tranzaksiyani o\'chirish'), findsOneWidget);

    await tester.tap(find.text('O\'chirish'));
    await tester.pumpAndSettle();

    final list = await container.read(transactionsControllerProvider.future);
    expect(list, isEmpty);
  });

  testWidgets(
      'a transfer never labels as income/expense, and a balance adjustment is visibly labeled',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      transactionFilterProvider.overrideWith((ref) => const TransactionFilter()),
    ]);
    addTearDown(container.dispose);
    final fromId = await container.read(accountRepositoryProvider).create(
        name: 'Naqd',
        type: AccountType.cash,
        openingBalance: const Money(1000000, uzs),
        icon: 'w');
    final toId = await container.read(accountRepositoryProvider).create(
        name: 'Karta',
        type: AccountType.bankCard,
        openingBalance: const Money(0, uzs),
        icon: 'c');
    final transferResult =
        await container.read(ledgerRepositoryProvider).transfer(
              fromId: fromId,
              toId: toId,
              amount: const Money(200000, uzs),
              occurredAt: DateTime(2026, 7, 10),
            );
    expect(transferResult.isOk, isTrue);
    await container.read(ledgerRepositoryProvider).adjustBalance(
          accountId: fromId,
          realBalance: const Money(750000, uzs),
          occurredAt: DateTime(2026, 7, 12),
        );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TransactionsScreen()),
    ));
    await tester.pumpAndSettle();

    // Transfer legs use their own labels, never "Kirim"/"Chiqim" as a row
    // title. The one remaining match for each is the fixed income/expense
    // summary card label (always rendered, independent of entry types).
    expect(find.text('O\'tkazma (chiqdi)'), findsOneWidget);
    expect(find.text('O\'tkazma (kirdi)'), findsOneWidget);
    expect(find.text('Kirim'), findsOneWidget);
    expect(find.text('Chiqim'), findsOneWidget);
    // Balance adjustment is visibly labeled.
    expect(find.text('Balans tuzatish'), findsOneWidget);
  });
}
