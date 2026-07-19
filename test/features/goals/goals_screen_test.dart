import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/goals/goal_model.dart';
import 'package:financial_assistant/features/goals/goals_screen.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  testWidgets('shows a card with the goal name and percent', (tester) async {
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
      child: const MaterialApp(home: GoalsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sayohat'), findsOneWidget);
    expect(find.textContaining('25'), findsWidgets); // 25% somewhere on the card
  });

  testWidgets('shows an empty state when there are no goals', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: GoalsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('maqsad'), findsWidgets); // empty-state copy
  });
}
