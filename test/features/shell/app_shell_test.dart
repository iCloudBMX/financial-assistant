import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/shell/app_shell.dart';

void main() {
  testWidgets('shows approved labels and preserves tab state', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['Bugun', 'Tarix', 'Reja', 'Maqsad', 'Tahlil']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(IndexedStack), findsOneWidget);
    expect(find.byKey(const PageStorageKey('home-tab')), findsOneWidget);

    await tester.tap(find.text('Tarix'));
    await tester.pumpAndSettle();
    expect(find.text('Tranzaksiyalar'), findsOneWidget); // Transactions app bar
    expect(find.byKey(const PageStorageKey('history-tab')), findsOneWidget);

    await tester.tap(find.text('Bugun'));
    await tester.pumpAndSettle();
    expect(find.byKey(const PageStorageKey('home-tab')), findsOneWidget);
  });

  testWidgets('announces selected tab and the global expense action', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('Bugun')),
      matchesSemantics(
        label: 'Bugun\nTab 1 of 5',
        isFocusable: true,
        isSelected: true,
        isButton: true,
        hasSelectedState: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('global-expense-action'))),
      matchesSemantics(
        label: 'Chiqim',
        isButton: true,
        isFocusable: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
  });

  testWidgets('keeps the global expense action available on all five tabs', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['Bugun', 'Tarix', 'Reja', 'Maqsad', 'Tahlil']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('global-expense-action')), findsOneWidget);
    }
  });

  testWidgets("Goals tab retains add-goal access beside the expense action", (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Maqsad'));
    await tester.pumpAndSettle();
    expect(find.text('Maqsadlar'), findsOneWidget); // Goals app bar

    final goalAction = find.descendant(
      of: find.byKey(const PageStorageKey('goals-tab')),
      matching: find.byType(FloatingActionButton),
    );
    expect(goalAction, findsOneWidget);
    expect(find.byKey(const Key('global-expense-action')), findsOneWidget);
    await tester.tap(goalAction);
    await tester.pumpAndSettle();

    expect(find.text('Yangi maqsad'), findsOneWidget);
    expect(find.byKey(const Key('goal-name')), findsOneWidget);
  });

  testWidgets('navigation reflows at 320px and 200 percent text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const AppShell(),
        ),
      ),
    );
    await tester.tap(find.text('Tahlil'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tahlil'), findsOneWidget);
    expect(find.byKey(const Key('global-expense-action')), findsOneWidget);
  });
}
