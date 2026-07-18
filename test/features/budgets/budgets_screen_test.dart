import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/budgets/budgets_controller.dart';
import 'package:financial_assistant/features/budgets/budgets_screen.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  testWidgets(
      'opening the limit sheet on a category that has a limit and pressing '
      'Saqlash unedited keeps the limit (no silent clear)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    // Category 1 (Oziq-ovqat) gets an existing monthly limit.
    await container
        .read(budgetsControllerProvider)
        .setMonthlyLimit(1, const Money(500000, uzs));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: BudgetsScreen()),
    ));
    await tester.pumpAndSettle();

    // Open the edit sheet for the first category (Oziq-ovqat).
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();

    // The sheet must be seeded with the parseable numeric form (no symbol).
    expect(find.text('500 000'), findsOneWidget);

    // Press Saqlash WITHOUT editing.
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    // The limit must be preserved, not wiped by the clear sentinel.
    final views =
        await container.read(categoryBudgetsProvider.future);
    expect(
        views.firstWhere((v) => v.category.id == 1).category.monthlyLimitMinor,
        500000);
  });
}
