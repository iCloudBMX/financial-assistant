import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/categories/category_model.dart';
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

  testWidgets(
      'tapping the kind chip toggles mandatory/o‘zgaruvchan and is reflected '
      'via categoryBudgetsProvider', (tester) async {
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

    // Category 1 (Oziq-ovqat) is `variable` by default.
    expect(find.text('o‘zgaruvchan'), findsWidgets);

    await tester.tap(find.text('o‘zgaruvchan').first);
    await tester.pumpAndSettle();

    final views = await container.read(categoryBudgetsProvider.future);
    expect(views.firstWhere((v) => v.category.id == 1).category.kind,
        CategoryKind.mandatory);
    expect(find.text('majburiy'), findsWidgets);
  });

  testWidgets(
      'setting a weekly limit via the sheet persists it and leaves the '
      'unedited monthly limit untouched', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await container
        .read(budgetsControllerProvider)
        .setMonthlyLimit(1, const Money(500000, uzs));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: BudgetsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('category-edit-weekly')), '20 000');
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    final views =
        await container.read(categoryBudgetsProvider.future);
    final cat1 = views.firstWhere((v) => v.category.id == 1).category;
    expect(cat1.monthlyLimitMinor, 500000, reason: 'unedited, preserved');
    expect(cat1.weeklyLimitMinor, 20000);
  });

  testWidgets(
      'a category over its monthly limit shows the over status as BOTH '
      'text and a warning icon (red reserved for over)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await container.read(accountRepositoryProvider).create(
        name: 'Naqd',
        type: AccountType.cash,
        openingBalance: const Money(10000000, uzs),
        icon: 'w');
    await container.read(budgetsControllerProvider).setMonthlyLimit(
        1, const Money(10000, uzs));
    await container.read(ledgerRepositoryProvider).addExpense(
          accountId: 1,
          amount: const Money(20000, uzs),
          categoryId: 1,
          occurredAt: DateTime.now(),
        );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: BudgetsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('limitdan oshgan'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
  });

  testWidgets(
      'the "Kategoriyalar" app-bar action opens the searchable category '
      'editor, listing categories and offering "Yangi kategoriya"',
      (tester) async {
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

    await tester.tap(find.byTooltip('Kategoriyalar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category-edit-search')), findsOneWidget);
    expect(find.byKey(const Key('category-edit-new')), findsOneWidget);
  });
}
