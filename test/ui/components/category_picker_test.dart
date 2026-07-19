import 'dart:ui' show Tristate;

import 'package:financial_assistant/data/categories/category_model.dart';
import 'package:financial_assistant/ui/components/category_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const categories = <Category>[
    Category(
      id: 1,
      name: 'Oziq-ovqat',
      icon: 'restaurant',
      isDefault: true,
      archived: false,
    ),
    Category(
      id: 2,
      name: 'Transport',
      icon: 'directions_car',
      isDefault: true,
      archived: false,
    ),
    Category(
      id: 3,
      name: 'Uy',
      icon: 'home',
      isDefault: true,
      archived: false,
      kind: CategoryKind.mandatory,
    ),
    Category(
      id: 4,
      name: 'Kommunal to‘lovlar',
      icon: 'bolt',
      isDefault: true,
      archived: false,
      kind: CategoryKind.mandatory,
    ),
    Category(
      id: 5,
      name: 'Ta’lim',
      icon: 'school',
      isDefault: true,
      archived: false,
    ),
    Category(
      id: 6,
      name: 'Eski kategoriya',
      icon: 'archive',
      isDefault: false,
      archived: true,
    ),
  ];

  testWidgets('shows four quick items then a searchable sheet', (tester) async {
    await tester.pumpWidget(
      _testApp(
        CategoryPicker(
          categories: categories,
          quickIds: const [1, 2, 3, 4],
          selectedId: 1,
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.byKey(const Key('quick-category')), findsNWidgets(4));

    await tester.tap(find.text('Kategoriya tanlash'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchBar), findsOneWidget);
  });

  testWidgets('quick selection emits an id without owning selection state', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(
      _testApp(
        CategoryPicker(
          categories: categories,
          quickIds: const [1, 2, 3, 4],
          selectedId: 1,
          onSelected: selected.add,
        ),
      ),
    );

    await tester.tap(find.text('Transport'));

    expect(selected, <int>[2]);
    expect(
      tester
          .getSemantics(find.byKey(const Key('quick-category-option-1')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('quick-category-option-2')))
          .flagsCollection
          .isSelected,
      Tristate.isFalse,
    );
  });

  testWidgets('quick list excludes archived ids and fills from active items', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        CategoryPicker(
          categories: categories,
          quickIds: const [6, 1],
          selectedId: null,
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.byKey(const Key('quick-category')), findsNWidgets(4));
    expect(find.text('Eski kategoriya'), findsNothing);
    expect(find.text('Oziq-ovqat'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
  });

  testWidgets('sheet groups active categories and excludes archived items', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        CategoryPicker(
          categories: categories,
          quickIds: const [1, 2, 3, 4],
          selectedId: 3,
          onSelected: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Kategoriya tanlash'));
    await tester.pumpAndSettle();

    expect(find.text('Majburiy'), findsOneWidget);
    expect(find.text('O‘zgaruvchan'), findsOneWidget);
    expect(find.text('Eski kategoriya'), findsNothing);
    expect(
      tester
          .getSemantics(find.byKey(const Key('category-option-3')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
  });

  testWidgets('search filters names and selection closes the sheet', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(
      _testApp(
        CategoryPicker(
          categories: categories,
          quickIds: const [1, 2, 3, 4],
          selectedId: null,
          onSelected: selected.add,
        ),
      ),
    );

    await tester.tap(find.text('Kategoriya tanlash'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(SearchBar),
        matching: find.byType(EditableText),
      ),
      'trans',
    );
    await tester.pump();

    final sheet = find.byKey(const Key('category-sheet'));
    expect(
      find.descendant(of: sheet, matching: find.text('Transport')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Oziq-ovqat')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('category-option-2')));
    await tester.pumpAndSettle();

    expect(selected, <int>[2]);
    expect(find.byType(SearchBar), findsNothing);
  });

  testWidgets('controls stay touchable at 320px and 200 percent text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(
        CategoryPicker(
          categories: categories,
          quickIds: const [1, 2, 3, 4],
          selectedId: 1,
          onSelected: (_) {},
        ),
        textScale: 2,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('category-picker-open'))).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.text('Kategoriya tanlash'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SearchBar), findsOneWidget);
  });
}

Widget _testApp(Widget child, {double textScale = 1}) => MaterialApp(
  builder: (context, appChild) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: appChild!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);
