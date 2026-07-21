import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/budgets/budgets_screen.dart';

void main() {
  testWidgets('manage mode archives a category (removed from the active list, '
      'history preserved via archived flag)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: BudgetsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('budgets-manage')));
    await tester.pumpAndSettle();

    // Archive the first category via its manage-mode remove button.
    await tester.tap(find.byKey(const Key('budgets-remove-1')));
    await tester.pumpAndSettle();

    final views = await container.read(categoryBudgetsProvider.future);
    expect(views.any((v) => v.category.id == 1), isFalse);
    // Still present when archived rows are included (history preserved).
    final all = await container
        .read(budgetRepositoryProvider)
        .categoriesWithBudgets(includeArchived: true);
    expect(all.any((c) => c.id == 1 && c.archived), isTrue);
  });
}
