import 'package:financial_assistant/features/shell/routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test(
    'exposes stable names and paths for the approved information architecture',
    () {
      final router = buildRouter(onboardingComplete: true);
      addTearDown(router.dispose);
      final routes = router.configuration.routes.whereType<GoRoute>();
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
}
