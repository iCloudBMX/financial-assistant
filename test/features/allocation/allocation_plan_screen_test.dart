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

  testWidgets('auto-selects the first source card on open', (tester) async {
    final (_, container, src, _) = await seed();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AllocationPlanScreen()),
    ));
    await tester.pumpAndSettle();
    // With cards available, the first card is auto-selected as the source: the
    // "choose a source" hint is gone and the add-rule button is enabled.
    expect(find.text('Avval manba kartani tanlang.'), findsNothing);
    expect(find.text('Hali qator yo\'q. "Yangi qator" bilan qo\'shing.'),
        findsOneWidget);
    final addBtn = tester.widget<TextButton>(
        find.byKey(const Key('plan-add-rule')));
    expect(addBtn.onPressed, isNotNull);
    // The source was persisted (first inserted account).
    final plan = await container.read(allocationPlanProvider.future);
    expect(plan.sourceAccountId, src);
  });

  testWidgets('a ledger-revision bump does not flash the whole screen to a '
      'spinner (source picker survives)', (tester) async {
    final (_, container, _, _) = await seed();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AllocationPlanScreen()),
    ));
    await tester.pumpAndSettle();
    // Baseline: the source picker is on screen, no spinner.
    expect(find.byKey(const Key('plan-source-picker')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // A swipe persists the new source, which bumps the ledger revision. The
    // picker's host must keep showing the last data during the reload instead
    // of collapsing to a full-screen spinner (which would kill the PageView
    // mid-swipe).
    container.read(ledgerRevisionProvider.notifier).state++;
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('plan-source-picker')), findsOneWidget);

    await tester.pumpAndSettle();
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

  testWidgets('swiping a rule row deletes it', (tester) async {
    final (_, container, src, dst) = await seed();
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
    expect(find.text('Kredit'), findsWidgets);

    // Swipe the row left to delete it.
    await tester.drag(
        find.byKey(const Key('plan-rule-0')), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // The row is gone and the empty-rules hint is back; the shorter list
    // was persisted.
    expect(find.text('Hali qator yo\'q. "Yangi qator" bilan qo\'shing.'),
        findsOneWidget);
    final plan = await container.read(allocationPlanProvider.future);
    expect(plan.rules, isEmpty);

    // Let the undo snackbar's backstop timer elapse.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('undo restores a swiped rule', (tester) async {
    final (_, container, src, dst) = await seed();
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

    await tester.drag(
        find.byKey(const Key('plan-rule-0')), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Bekor qilish'), findsOneWidget);
    final afterDelete = await container.read(allocationPlanProvider.future);
    expect(afterDelete.rules, isEmpty);

    // Tap undo -> the rule comes back, persisted.
    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    final restored = await container.read(allocationPlanProvider.future);
    expect(restored.rules.length, 1);
    expect(restored.rules.first.destinationAccountId, dst);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
