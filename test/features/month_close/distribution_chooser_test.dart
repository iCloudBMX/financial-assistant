import 'package:drift/native.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/goals/goal_model.dart';
import 'package:financial_assistant/features/goals/goal_contribute_sheet.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('goal contribute sheet prefills the initial amount',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final repo = container.read(goalRepositoryProvider);
    await repo.create(GoalDraft(
      name: 'Sayohat',
      targetAmountMinor: 1000000,
      startDate: DateTime(2026, 1, 1),
    ));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) => Scaffold(
              body: Center(child: ElevatedButton(
                  onPressed: () => showGoalContributeSheet(context, ref,
                      goalId: 1,
                      initialAmount:
                          const Money(750000, CurrencyRegistry.uzs)),
                  child: const Text('open'))),
            )),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // formatNumber for UZS groups thousands with spaces.
    expect(find.text('750 000'), findsOneWidget);
  });
}
