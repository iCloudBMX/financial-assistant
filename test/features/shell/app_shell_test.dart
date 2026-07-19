import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/shell/app_shell.dart';

void main() {
  testWidgets('shell shows Home then switches to Transactions', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AppShell()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Bosh sahifa'), findsOneWidget); // Home app bar

    await tester.tap(find.text('Tranzaksiya'));
    await tester.pumpAndSettle();
    expect(find.text('Tranzaksiyalar'), findsOneWidget); // Transactions app bar
  });

  testWidgets("Goals tab '+' opens the add-goal sheet, not expense entry",
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AppShell()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Goal'));
    await tester.pumpAndSettle();
    expect(find.text('Maqsadlar'), findsOneWidget); // Goals app bar

    // Regression: the shell's global expense-entry FAB used to paint on top of
    // the Goals screen's own FAB and swallow the tap, opening the expense sheet
    // instead of the add-goal sheet. On the Goals tab the global FAB is hidden,
    // so the only FAB is the add-goal one.
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // The add-goal sheet is up (its title + name field), NOT the expense sheet.
    expect(find.text('Yangi maqsad'), findsOneWidget);
    expect(find.byKey(const Key('goal-name')), findsOneWidget);
  });
}
