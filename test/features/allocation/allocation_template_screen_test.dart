import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/allocation/allocation_models.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/allocation/allocation_template_screen.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  testWidgets('template editor lists the seeded directions', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: AllocationTemplateScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Minimal zaxira'), findsOneWidget);
    expect(find.text('O‘zgaruvchan budjet'), findsOneWidget);
    await db.close();
  });

  testWidgets(
      'each rule card shows its own rule-type label: fixed, percentage, '
      'goal, and remaining are all visually distinct', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await container.read(allocationRepositoryProvider).saveTemplate(const [
      AllocationDirection(
          bucketKey: 'mandatoryExpenses',
          method: AllocationMethod.fixedAmount,
          amount: Money(500000, uzs)),
      AllocationDirection(
          bucketKey: 'minReserve',
          method: AllocationMethod.percentage,
          percentBp: 1000),
      AllocationDirection(
          bucketKey: 'goal:1', method: AllocationMethod.goalBased),
      AllocationDirection(
          bucketKey: 'variableBudget', method: AllocationMethod.remaining),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AllocationTemplateScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Belgilangan summa'), findsOneWidget);
    expect(find.text('Foiz'), findsOneWidget);
    expect(find.text('Maqsad asosida'), findsOneWidget);
    expect(find.text('Qolgan summa'), findsOneWidget);
  });

  testWidgets('dragging a rule card by its handle reorders the list, and '
      'Saqlash persists the new order', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await container.read(allocationRepositoryProvider).saveTemplate(const [
      AllocationDirection(
          bucketKey: 'mandatoryExpenses',
          method: AllocationMethod.fixedAmount,
          amount: Money(500000, uzs)),
      AllocationDirection(
          bucketKey: 'minReserve',
          method: AllocationMethod.percentage,
          percentBp: 1000),
      AllocationDirection(
          bucketKey: 'variableBudget', method: AllocationMethod.remaining),
    ]);
    final before = (await container.read(allocationRepositoryProvider).template())
        .directions
        .map((d) => d.bucketKey)
        .toList();

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AllocationTemplateScreen()),
    ));
    await tester.pumpAndSettle();

    final handle = find.byIcon(Icons.drag_handle).first;
    await tester.drag(handle, const Offset(0, 260));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();

    final after = (await container.read(allocationRepositoryProvider).template())
        .directions
        .map((d) => d.bucketKey)
        .toList();
    expect(after, isNot(equals(before)),
        reason: 'dragging the first handle down should change the saved '
            'priority order');
    expect(after.toSet(), before.toSet(),
        reason: 'reordering must not lose or duplicate a direction');

    // The "saved" snackbar auto-dismisses; let its backstop timer elapse so
    // no timer outlives the test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
