import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/categories/category_edit_sheet.dart';

void main() {
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
      'form, seeded with the current name, no silent clear on unedited '
      'Saqlash', (tester) async {
    final container = await pumpDirectEdit(tester, categoryId: 1);

    expect(find.byKey(const Key('category-edit-search')), findsNothing,
        reason: 'direct edit of a known category skips the search list');
    expect(find.byKey(const Key('category-edit-name')), findsOneWidget);

    final nameField =
        tester.widget<TextField>(find.byKey(const Key('category-edit-name')));
    final originalName = nameField.controller!.text;

    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    final cats = await container.read(categoriesProvider.future);
    expect(cats.firstWhere((c) => c.id == 1).name, originalName);
  });

  testWidgets('editing the name persists it', (tester) async {
    final container = await pumpDirectEdit(tester, categoryId: 1);

    await tester.enterText(
        find.byKey(const Key('category-edit-name')), 'Ovqatlanish');
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    final cats = await container.read(categoriesProvider.future);
    final cat1 = cats.firstWhere((c) => c.id == 1);
    expect(cat1.name, 'Ovqatlanish');
  });

  testWidgets('no monthly-limit field is shown', (tester) async {
    await pumpDirectEdit(tester, categoryId: 1);
    expect(find.byKey(const Key('category-edit-monthly')), findsNothing);
    expect(find.text('Oylik reja'), findsNothing);
    expect(find.text('Joriy holat'), findsNothing);
  });

  testWidgets('archiving removes the category from the active list',
      (tester) async {
    final container = await pumpDirectEdit(tester, categoryId: 1);

    await tester.ensureVisible(find.byKey(const Key('category-edit-archive')));
    await tester.tap(find.byKey(const Key('category-edit-archive')));
    await tester.pumpAndSettle();

    final cats = await container.read(categoriesProvider.future);
    expect(cats.firstWhere((c) => c.id == 1).archived, isTrue);
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

    final cats = await container.read(categoriesProvider.future);
    expect(cats.any((c) => c.name == 'Sport'), isTrue);
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
