// test/features/goals/goal_contribute_sheet_test.dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/goals/goal_model.dart';
import 'package:financial_assistant/features/goals/goal_contribute_sheet.dart';
import 'package:financial_assistant/features/goals/goal_controller.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  testWidgets('contributing adds to the goal saved amount', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final repo = container.read(goalRepositoryProvider);
    final id = await repo.create(GoalDraft(
      name: 'G',
      targetAmountMinor: 1000000,
      startDate: DateTime(2026, 1, 1),
    ));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () =>
                  showGoalContributeSheet(context, ref, goalId: id),
              child: const Text('open'),
            );
          }),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('contrib-amount')), '300000');
    await tester.tap(find.byKey(const Key('contrib-save')));
    await tester.pumpAndSettle();

    expect(await repo.savedFor(id), 300000);
  });

  testWidgets(
      'withdraw exceeding saved keeps the sheet open and shows an error',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final repo = container.read(goalRepositoryProvider);
    final id = await repo.create(GoalDraft(
      name: 'G',
      targetAmountMinor: 1000000,
      startDate: DateTime(2026, 1, 1),
    ));
    final ctrl = container.read(goalControllerProvider);
    final ok = await ctrl.contribute(
        goalId: id, amount: const Money(100000, CurrencyRegistry.uzs));
    expect(ok.isOk, isTrue);
    expect(await repo.savedFor(id), 100000);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () => showGoalContributeSheet(context, ref,
                  goalId: id, withdraw: true),
              child: const Text('open'),
            );
          }),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('contrib-amount')), '500000');
    await tester.tap(find.byKey(const Key('contrib-save')));
    await tester.pumpAndSettle();

    // Sheet must STAY OPEN on a failed withdrawal, not silently pop.
    expect(find.byKey(const Key('contrib-save')), findsOneWidget);
    expect(find.textContaining("Jamg'armadan ko'p yechib bo'lmaydi"),
        findsOneWidget);
    expect(await repo.savedFor(id), 100000);
  });

  testWidgets('withdraw within saved succeeds and closes the sheet',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final repo = container.read(goalRepositoryProvider);
    final id = await repo.create(GoalDraft(
      name: 'G',
      targetAmountMinor: 1000000,
      startDate: DateTime(2026, 1, 1),
    ));
    final ctrl = container.read(goalControllerProvider);
    final ok = await ctrl.contribute(
        goalId: id, amount: const Money(100000, CurrencyRegistry.uzs));
    expect(ok.isOk, isTrue);
    expect(await repo.savedFor(id), 100000);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () => showGoalContributeSheet(context, ref,
                  goalId: id, withdraw: true),
              child: const Text('open'),
            );
          }),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('contrib-amount')), '40000');
    await tester.tap(find.byKey(const Key('contrib-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('contrib-save')), findsNothing);
    expect(await repo.savedFor(id), 60000);
  });

  testWidgets('zero/empty amount shows a client-side error and does not submit',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final repo = container.read(goalRepositoryProvider);
    final id = await repo.create(GoalDraft(
      name: 'G',
      targetAmountMinor: 1000000,
      startDate: DateTime(2026, 1, 1),
    ));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () =>
                  showGoalContributeSheet(context, ref, goalId: id),
              child: const Text('open'),
            );
          }),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('contrib-amount')), '0');
    await tester.tap(find.byKey(const Key('contrib-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('contrib-save')), findsOneWidget);
    expect(find.textContaining("Summa 0 dan katta bo'lishi kerak"),
        findsOneWidget);
    expect(await repo.savedFor(id), 0);
  });
}
