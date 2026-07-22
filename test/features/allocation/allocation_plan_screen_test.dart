import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/allocation/allocation_plan.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/allocation/allocation_plan_controller.dart';
import 'package:financial_assistant/features/allocation/allocation_plan_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  Future<(AppDatabase, ProviderContainer, int, int)> seed() async {
    final db = AppDatabase(NativeDatabase.memory());
    final src = await db.into(db.accountsTable).insert(
        AccountsTableCompanion.insert(
            name: 'Sarf', type: 'bankCard',
            openingBalanceMinor: const Value(2000000),
            role: const Value('spending')));
    final dst = await db.into(db.accountsTable).insert(
        AccountsTableCompanion.insert(
            name: 'Kredit', type: 'bankCard',
            openingBalanceMinor: const Value(0), role: const Value('credit')));
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(() {
      container.dispose();
      db.close();
    });
    return (db, container, src, dst);
  }

  testWidgets('shows a hint until a source is chosen', (tester) async {
    final (_, container, _, _) = await seed();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AllocationPlanScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Avval manba kartani tanlang.'), findsOneWidget);
    // Add-rule button disabled with no source chosen.
    final addBtn = tester.widget<TextButton>(
        find.byKey(const Key('plan-add-rule')));
    expect(addBtn.onPressed, isNull);
  });

  testWidgets('applying a saved rule moves money off the source card',
      (tester) async {
    final (db, container, src, dst) = await seed();
    // Pre-seed a source + one 1,000,000 rule to the destination card.
    await container.read(allocationPlanControllerProvider).setSource(src);
    await container.read(allocationPlanControllerProvider).saveRules([
      AllocationRule(
          destinationAccountId: dst,
          amount: const Money(1000000, uzs),
          sortOrder: 0),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AllocationPlanScreen()),
    ));
    await tester.pumpAndSettle();

    // The rule row renders the destination name + amount.
    expect(find.text('Kredit'), findsWidgets);

    // Apply -> confirm sheet -> Bajarish.
    await tester.tap(find.byKey(const Key('plan-apply')));
    await tester.pumpAndSettle();
    expect(find.text('Bajarish'), findsOneWidget);
    await tester.tap(find.text('Bajarish'));
    await tester.pumpAndSettle();

    // Source dropped by 1,000,000 (2,000,000 opening -> 1,000,000).
    final entries = await db.select(db.transactionsTable).get();
    int balance(int accId, int opening) =>
        opening +
        entries
            .where((e) => e.accountId == accId)
            .fold(0, (s, e) => s + e.amountMinor);
    expect(balance(src, 2000000), 1000000);
    expect(balance(dst, 0), 1000000);

    // The confirmation snackbar auto-dismisses; let its backstop timer
    // elapse so no timer outlives the test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
