import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
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

  // `ReorderableDragStartListener` (the default drag handle used by
  // `ReorderableListView`) starts its drag from a long press, then tracks
  // pointer movement until release — all as ONE continuous pointer gesture.
  // `tester.longPress()` followed by a separate `tester.drag()` performs two
  // independent down/up sequences and never registers as a drag, so this
  // helper keeps a single `TestGesture` down across the long-press wait and
  // the move, mirroring the pattern Flutter's own reorderable-list tests use.
  Future<void> longPressDrag(
      WidgetTester tester, Offset start, Offset moveBy) async {
    final gesture = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + kPressTimeout);
    await gesture.moveBy(moveBy);
    await tester.pump(kPressTimeout);
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('lists active categories and can archive one', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(const Key('category-reorder-list')), findsOneWidget);

    // Archive is swipe-driven now: swipe the row left (endToStart).
    await tester.drag(find.byKey(const ValueKey(1)), const Offset(-500, 0));
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

    // The FAB opens the create form directly (createNew: true), skipping the
    // searchable list — landing straight on the name field.
    await tester.tap(find.byKey(const Key('category-add')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category-edit-name')), findsOneWidget);
  });

  testWidgets(
      'drag-reordering a category persists the post-removal index the way '
      'onReorderItem hands it back', (tester) async {
    final container = await pumpScreen(tester);

    final before = await container.read(categoriesProvider.future);
    final beforeIds = [for (final c in before) if (!c.archived) c.id];
    // The default-category seed guarantees at least 4 active rows, which is
    // enough room to drag past two neighbours in each direction.
    expect(beforeIds.length, greaterThanOrEqualTo(4));

    final itemHeight =
        tester.getSize(find.byKey(ValueKey(beforeIds[0]))).height;

    // Drag the first row down, past the following two rows. Empirically,
    // `ReorderableListView`'s swap threshold needs more than N full row
    // heights of travel to register N swaps (it's based on where the
    // dragged proxy's center crosses a sibling's midpoint, not a clean
    // per-row multiple), so 3.5x rows is calibrated to reliably land 2
    // swaps below without overshooting to 3.
    await longPressDrag(
      tester,
      tester.getCenter(find.byKey(ValueKey(beforeIds[0]))),
      Offset(0, itemHeight * 3.5),
    );

    final afterDown = await container.read(categoriesProvider.future);
    final afterDownIds = [for (final c in afterDown) if (!c.archived) c.id];

    // A drag from index 0 past two rows below should land the moved item at
    // index 2 in the final (post-removal) order: [1, 2, 0, 3, 4, ...].
    final expectedDown = [...beforeIds]..removeAt(0);
    expectedDown.insert(2, beforeIds[0]);
    expect(afterDownIds, expectedDown,
        reason: 'downward drag of ${beforeIds[0]} did not land at the '
            'expected post-removal index; got $afterDownIds');

    // Drag the same category back up, past the two rows now above it, and
    // confirm it returns to its original slot.
    await longPressDrag(
      tester,
      tester.getCenter(find.byKey(ValueKey(beforeIds[0]))),
      Offset(0, -itemHeight * 3.5),
    );

    final afterUp = await container.read(categoriesProvider.future);
    final afterUpIds = [for (final c in afterUp) if (!c.archived) c.id];
    expect(afterUpIds, beforeIds,
        reason: 'upward drag of ${beforeIds[0]} did not restore the '
            'original order; got $afterUpIds');
  });
}
