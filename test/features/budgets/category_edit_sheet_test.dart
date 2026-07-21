import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/budget/budget_repository.dart';
import 'package:financial_assistant/data/categories/category_model.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/budgets/budgets_controller.dart';
import 'package:financial_assistant/features/budgets/category_edit_sheet.dart';

/// Wraps a real [BudgetRepository] but fails `setCategoryLimits`, to prove
/// that `BudgetsController.saveCategory` rolls back the rename/icon writes
/// when the limit write in the same transaction fails (MINOR #5: the
/// category-editor save is a multi-write sequence -- rename, setIcon, and
/// the monthly `_applyLimit` write -- that must be all-or-nothing). This
/// fake still implements `setCategoryKind` because `BudgetRepository` keeps
/// that method (the budget page UI no longer uses it, but the data-model
/// interface is unchanged).
class _ThrowingBudgetRepository implements BudgetRepository {
  _ThrowingBudgetRepository(this._delegate);
  final BudgetRepository _delegate;

  @override
  Future<void> setCategoryKind(int id, CategoryKind kind) =>
      _delegate.setCategoryKind(id, kind);

  @override
  Future<void> setCategoryLimits(
    int id, {
    int? monthlyLimitMinor,
    bool clearMonthly = false,
    int? weeklyLimitMinor,
    bool clearWeekly = false,
  }) async {
    throw Exception('forced limit-write failure');
  }

  @override
  Future<List<Category>> categoriesWithBudgets(
          {bool includeArchived = false}) =>
      _delegate.categoriesWithBudgets(includeArchived: includeArchived);
}

void main() {
  const uzs = CurrencyRegistry.uzs;

  Widget harness({int? categoryId}) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showCategoryEditSheet(context, categoryId: categoryId),
              child: const Text('open'),
            ),
          ),
        ),
      );

  Future<ProviderContainer> pumpDirectEdit(
    WidgetTester tester, {
    required int categoryId,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: harness(categoryId: categoryId),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return container;
  }

  Future<ProviderContainer> pumpList(WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: harness(),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
      'direct-edit mode (an existing categoryId) opens straight to the '
      'form, seeded with the current name/limits, no silent clear on '
      'unedited Saqlash', (tester) async {
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
      child: harness(categoryId: 1),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category-edit-search')), findsNothing,
        reason: 'direct edit of a known category skips the search list');
    expect(find.text('500 000'), findsOneWidget);

    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    final views = await container.read(categoryBudgetsProvider.future);
    expect(
        views.firstWhere((v) => v.category.id == 1).category.monthlyLimitMinor,
        500000);
  });

  testWidgets('editing the name and the Oylik reja persists both',
      (tester) async {
    final container = await pumpDirectEdit(tester, categoryId: 1);

    await tester.enterText(
        find.byKey(const Key('category-edit-name')), 'Ovqatlanish');
    await tester.enterText(
        find.byKey(const Key('category-edit-monthly')), '500 000');
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    final views = await container.read(categoryBudgetsProvider.future);
    final cat1 = views.firstWhere((v) => v.category.id == 1).category;
    expect(cat1.name, 'Ovqatlanish');
    expect(cat1.monthlyLimitMinor, 500000);
  });

  testWidgets('there is no Turi (kind) chooser and no weekly field',
      (tester) async {
    await pumpDirectEdit(tester, categoryId: 1);
    expect(find.text('Turi'), findsNothing);
    expect(find.byKey(const Key('category-edit-weekly')), findsNothing);
    expect(find.text('Oylik reja'), findsOneWidget);
  });

  testWidgets('archiving removes the category from the default budgets list',
      (tester) async {
    final container = await pumpDirectEdit(tester, categoryId: 1);

    await tester.ensureVisible(find.byKey(const Key('category-edit-archive')));
    await tester.tap(find.byKey(const Key('category-edit-archive')));
    await tester.pumpAndSettle();

    final views = await container.read(categoryBudgetsProvider.future);
    expect(views.any((v) => v.category.id == 1), isFalse);
  });

  testWidgets(
      'no-categoryId opens a searchable list; typing filters, and tapping '
      'a result drills into its edit form', (tester) async {
    await pumpList(tester);

    expect(find.byKey(const Key('category-edit-search')), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('category-edit-search')), 'Transport');
    await tester.pumpAndSettle();
    expect(find.text('Oziq-ovqat'), findsNothing);
    // "Transport" now appears twice: the search field's own typed text and
    // the one remaining filtered result.
    expect(find.text('Transport'), findsNWidgets(2));

    await tester.tap(find.text('Transport').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category-edit-name')), findsOneWidget);
    expect(find.text('Transport'), findsWidgets); // now seeded in the field
  });

  testWidgets('"Yangi kategoriya" creates a new category on Saqlash',
      (tester) async {
    final container = await pumpList(tester);

    await tester.tap(find.byKey(const Key('category-edit-new')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('category-edit-name')), 'Sport');
    // A settle beat for the name listener's setState to flip Saqlash
    // enabled before the tap is dispatched.
    await tester.pump();
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    final views = await container.read(categoryBudgetsProvider.future);
    expect(views.any((v) => v.category.name == 'Sport'), isTrue);
  });

  testWidgets(
      'a failed limit write rolls back the rename/icon edits in the '
      'same Saqlash (atomic save, no partial category edit)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final realBudgetRepo = DriftBudgetRepository(db);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      budgetRepositoryProvider.overrideWithValue(
        _ThrowingBudgetRepository(realBudgetRepo),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: harness(categoryId: 1),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('category-edit-name')), 'Ovqatlanish');
    await tester.tap(find.byKey(const Key('category-edit-icon-directions_car')));
    await tester.enterText(
        find.byKey(const Key('category-edit-monthly')), '500 000');
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    // The sheet stays open (Saqlash did not pop as a success) and the
    // rename/icon/limit edits were all rolled back along with the failed
    // limit write.
    expect(find.byKey(const Key('category-edit-name')), findsOneWidget);
    final views = await container.read(categoryBudgetsProvider.future);
    final cat1 = views.firstWhere((v) => v.category.id == 1).category;
    expect(cat1.name, isNot('Ovqatlanish'));
    expect(cat1.icon, isNot('directions_car'));
    expect(cat1.monthlyLimitMinor, isNot(500000));

    // The error snackbar auto-dismisses; let its backstop timer elapse so no
    // timer outlives the test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('Saqlash stays disabled while the name is empty',
      (tester) async {
    await pumpList(tester);
    await tester.tap(find.byKey(const Key('category-edit-new')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('category-edit-name')), '');
    await tester.pumpAndSettle();

    final saveButton = tester.widget<FilledButton>(
      find.descendant(
          of: find.byKey(const Key('category-edit-save')),
          matching: find.byType(FilledButton)),
    );
    expect(saveButton.onPressed, isNull);
  });
}
