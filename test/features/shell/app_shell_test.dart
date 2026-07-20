import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/shell/routes.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('shows approved labels and preserves tab state', (tester) async {
    await _pumpShell(tester);

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

  testWidgets('announces the selected tab', (tester) async {
    await _pumpShell(tester);

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
  });

  testWidgets('Goals tab retains add-goal access', (tester) async {
    await _pumpShell(tester);

    await tester.tap(find.text('Maqsad'));
    await tester.pumpAndSettle();
    expect(find.text('Maqsadlar'), findsOneWidget); // Goals app bar

    final goalAction = find.descendant(
      of: find.byKey(const PageStorageKey('goals-tab')),
      matching: find.byType(FloatingActionButton),
    );
    expect(goalAction, findsOneWidget);
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
    await _pumpShell(tester, textScale: 2, settle: false);
    await tester.tap(find.text('Tahlil'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tahlil'), findsOneWidget);
  });
}

Future<GoRouter> _pumpShell(
  WidgetTester tester, {
  double textScale = 1,
  bool settle = true,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(container.dispose);
  final router = buildRouter(onboardingComplete: true);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        routerConfig: router,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return router;
}
