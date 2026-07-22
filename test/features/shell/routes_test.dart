import 'package:drift/native.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/features/shell/routes.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test(
    'exposes stable names and paths for the approved information architecture',
    () {
      final router = buildRouter(onboardingComplete: true);
      addTearDown(router.dispose);
      final routes = RouteBase.routesRecursively(
        router.configuration.routes,
      ).whereType<GoRoute>();
      final pathByName = <String, String>{
        for (final route in routes) ?route.name: route.path,
      };

      expect(pathByName, containsPair('home', '/'));
      expect(pathByName, containsPair('history', '/history'));
      expect(pathByName, containsPair('plan', '/plan'));
      expect(pathByName, containsPair('goals', '/goals'));
      expect(pathByName, containsPair('reports', '/reports'));
      expect(pathByName, containsPair('settings', '/settings'));
      expect(pathByName, containsPair('accounts', '/accounts'));
    },
  );

  test(
    'named destinations resolve without breaking existing deep-link paths',
    () {
      final router = buildRouter(onboardingComplete: true);
      addTearDown(router.dispose);

      expect(router.namedLocation(RouteNames.home), '/');
      expect(router.namedLocation(RouteNames.history), '/history');
      expect(router.namedLocation(RouteNames.plan), '/plan');
      expect(router.namedLocation(RouteNames.goals), '/goals');
      expect(router.namedLocation(RouteNames.reports), '/reports');
      expect(router.namedLocation(RouteNames.settings), '/settings');
      expect(router.namedLocation(RouteNames.accounts), '/accounts');
    },
  );

  testWidgets('tab selection updates the URI and survives settings push/back', (
    tester,
  ) async {
    final router = buildRouter(onboardingComplete: true);
    addTearDown(router.dispose);
    await _pumpRouterApp(tester, router);

    router.goNamed(RouteNames.history);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/history');
    expect(
      tester.getSemantics(find.text('Tarix')),
      matchesSemantics(
        label: 'Tarix\nTab 2 of 5',
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

    await tester.tap(find.text('Taqsimlash'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/plan');
    expect(find.text('Taqsimlash rejasi'), findsOneWidget); // AllocationPlanScreen AppBar

    router.pushNamed(RouteNames.settings);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/settings');
    expect(find.text('Sozlamalar'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/plan');
    expect(find.text('Taqsimlash rejasi'), findsOneWidget); // AllocationPlanScreen AppBar
    expect(
      tester.getSemantics(find.text('Taqsimlash')),
      matchesSemantics(
        label: 'Taqsimlash\nTab 3 of 5',
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

  testWidgets('route changes retain observable Home scroll state', (
    tester,
  ) async {
    // Keep the real Home screen vertically scrollable without introducing
    // narrow-width layout concerns that are covered by the shell's dedicated
    // 320 px/200% test.
    tester.view.physicalSize = const Size(800, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = buildRouter(onboardingComplete: true);
    addTearDown(router.dispose);
    await _pumpRouterApp(tester, router);

    final homeList = find.descendant(
      of: find.byKey(const PageStorageKey('home-tab')),
      matching: find.byType(ListView),
    );
    expect(homeList, findsOneWidget);
    await tester.drag(homeList, const Offset(0, -400));
    await tester.pumpAndSettle();
    final before = _scrollOffset(tester, homeList);
    expect(before, greaterThan(0));

    router.goNamed(RouteNames.history);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/history');
    router.goNamed(RouteNames.home);
    await tester.pumpAndSettle();

    final restoredHomeList = find.descendant(
      of: find.byKey(const PageStorageKey('home-tab')),
      matching: find.byType(ListView),
    );
    expect(_scrollOffset(tester, restoredHomeList), closeTo(before, 0.1));
  });

  testWidgets('all five deep links select the matching retained branch', (
    tester,
  ) async {
    final router = buildRouter(onboardingComplete: true);
    addTearDown(router.dispose);
    await _pumpRouterApp(tester, router);
    const destinations = [
      (RouteNames.home, RoutePaths.home, 0, 'home-tab'),
      (RouteNames.history, RoutePaths.history, 1, 'history-tab'),
      (RouteNames.plan, RoutePaths.plan, 2, 'plan-tab'),
      (RouteNames.goals, RoutePaths.goals, 3, 'goals-tab'),
      (RouteNames.reports, RoutePaths.reports, 4, 'reports-tab'),
    ];

    for (final (name, path, index, key) in destinations) {
      router.goNamed(name);
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, path);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        index,
      );
      expect(find.byKey(PageStorageKey(key)), findsOneWidget);
    }
  });

  testWidgets('Accounts push and back preserve the active Home branch', (
    tester,
  ) async {
    final router = buildRouter(onboardingComplete: true);
    addTearDown(router.dispose);
    await _pumpRouterApp(tester, router);

    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/accounts');
    expect(find.text('Hisoblar'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(find.byKey(const PageStorageKey('home-tab')), findsOneWidget);
  });
}

Future<void> _pumpRouterApp(WidgetTester tester, GoRouter router) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

double _scrollOffset(WidgetTester tester, Finder listView) {
  // Target the vertical (Home) scrollable specifically: the redesigned Home
  // also hosts a horizontal quick-actions scroller, so an unqualified
  // `byType(Scrollable)` is ambiguous whenever that row stays on screen.
  final scrollable = find.descendant(
    of: listView,
    matching: find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    ),
  );
  return tester.state<ScrollableState>(scrollable).position.pixels;
}
