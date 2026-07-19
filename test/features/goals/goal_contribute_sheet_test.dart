// test/features/goals/goal_contribute_sheet_test.dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/goals/goal_model.dart';
import 'package:financial_assistant/data/goals/goal_repository.dart';
import 'package:financial_assistant/features/goals/goal_contribute_sheet.dart';
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
}
