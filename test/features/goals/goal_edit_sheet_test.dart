import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/goals/goal_repository.dart';
import 'package:financial_assistant/features/goals/goal_edit_sheet.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  testWidgets('creating a goal saves it with the entered target', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () => showGoalEditSheet(context, ref),
              child: const Text('open'),
            );
          }),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('goal-name')), 'Avto');
    await tester.enterText(find.byKey(const Key('goal-target')), '5000000');
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();

    final goals = await container.read(goalRepositoryProvider).list();
    expect(goals.single.name, 'Avto');
    expect(goals.single.targetAmountMinor, 5000000);
  });
}
