// test/features/goals/goal_detail_screen_test.dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/goals/goal_model.dart';
import 'package:financial_assistant/data/goals/goal_repository.dart';
import 'package:financial_assistant/features/goals/goal_completed_dialog.dart';
import 'package:financial_assistant/features/goals/goal_controller.dart';
import 'package:financial_assistant/features/goals/goal_detail_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  testWidgets('detail lists the contribution history', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final repo = container.read(goalRepositoryProvider);
    final id = await repo.create(GoalDraft(
      name: 'Sayohat',
      targetAmountMinor: 1000000,
      startDate: DateTime(2026, 1, 1),
    ));
    await repo.addContribution(
        goalId: id, signedAmountMinor: 250000, source: ContributionSource.manual);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: GoalDetailScreen(goalId: id)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sayohat'), findsWidgets);
    expect(find.byKey(const Key('contribution-row')), findsOneWidget);
  });

  testWidgets(
      'move surplus action shifts excess from the completed goal to another goal',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final repo = container.read(goalRepositoryProvider);
    final idA = await repo.create(GoalDraft(
      name: 'GoalA',
      targetAmountMinor: 1000000,
      startDate: DateTime(2026, 1, 1),
    ));
    final idB = await repo.create(GoalDraft(
      name: 'GoalB',
      targetAmountMinor: 2000000,
      startDate: DateTime(2026, 1, 1),
    ));

    final ctrl = container.read(goalControllerProvider);
    final ok = await ctrl.contribute(
        goalId: idA, amount: const Money(1500000, CurrencyRegistry.uzs));
    expect(ok.isOk, isTrue);
    expect(await repo.savedFor(idA), 1500000);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () =>
                  showGoalCompletedDialog(context, ref, goalId: idA),
              child: const Text('open'),
            );
          }),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text("Ortiqchani ko'chirish"), findsOneWidget);
    await tester.tap(find.text("Ortiqchani ko'chirish"));
    await tester.pumpAndSettle();

    expect(find.text('GoalB'), findsOneWidget);
    await tester.tap(find.text('GoalB'));
    await tester.pumpAndSettle();

    expect(await repo.savedFor(idA), 1000000);
    expect(await repo.savedFor(idB), 500000);
  });
}
