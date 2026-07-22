import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/categories/category_management_screen.dart';

void main() {
  Future<ProviderContainer> pumpScreen(WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CategoryManagementScreen()),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('lists active categories and can archive one', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(const Key('category-reorder-list')), findsOneWidget);

    await tester.tap(find.byKey(const Key('category-archive-1')));
    await tester.pumpAndSettle();

    // The seeded category list is long enough that the archived section
    // renders below the fold at the default test viewport size, so it must
    // be scrolled into view before a default (onstage-only) finder sees it.
    // `scrollUntilVisible`'s default scrollable lookup fails here because
    // there are two Scrollables (the outer screen ListView and the inner,
    // non-scrolling ReorderableListView), so the outer one is targeted
    // explicitly by type.
    final restoreFinder =
        find.byKey(const Key('category-restore-1'), skipOffstage: false);
    await tester.scrollUntilVisible(
      restoreFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category-restore-1')), findsOneWidget);
    expect(find.textContaining('Oylik reja'), findsNothing);
  });

  testWidgets('opens the create sheet from the add FAB', (tester) async {
    await pumpScreen(tester);

    // The FAB opens the same searchable editor sheet used elsewhere
    // (`showCategoryEditSheet(context)` with no categoryId), which lands on
    // the search list first; "Yangi kategoriya" is the actual create entry.
    await tester.tap(find.byKey(const Key('category-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category-edit-new')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category-edit-name')), findsOneWidget);
  });
}
