import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/budgets/budgets_controller.dart';
import 'package:financial_assistant/features/budgets/category_edit_sheet.dart';

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

  testWidgets('editing the name and a weekly limit persists both changes',
      (tester) async {
    final container = await pumpDirectEdit(tester, categoryId: 1);

    await tester.enterText(
        find.byKey(const Key('category-edit-name')), 'Ovqatlanish');
    await tester.enterText(
        find.byKey(const Key('category-edit-weekly')), '20 000');
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    final views = await container.read(categoryBudgetsProvider.future);
    final cat1 = views.firstWhere((v) => v.category.id == 1).category;
    expect(cat1.name, 'Ovqatlanish');
    expect(cat1.weeklyLimitMinor, 20000);
  });

  testWidgets('toggling kind to majburiy persists', (tester) async {
    final container = await pumpDirectEdit(tester, categoryId: 1);

    await tester.tap(find.text('majburiy'));
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    final views = await container.read(categoryBudgetsProvider.future);
    expect(views.firstWhere((v) => v.category.id == 1).category.kind.name,
        'mandatory');
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
