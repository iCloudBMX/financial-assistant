import 'package:go_router/go_router.dart';
import '../accounts/accounts_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../settings/settings_screen.dart';
import 'app_shell.dart';

abstract final class RouteNames {
  const RouteNames._();

  static const home = 'home';
  static const history = 'history';
  static const plan = 'plan';
  static const goals = 'goals';
  static const reports = 'reports';
  static const onboarding = 'onboarding';
  static const settings = 'settings';
  static const accounts = 'accounts';
}

abstract final class RoutePaths {
  const RoutePaths._();

  static const home = '/';
  static const history = '/history';
  static const plan = '/plan';
  static const goals = '/goals';
  static const reports = '/reports';
  static const onboarding = '/onboarding';
  static const settings = '/settings';
  static const accounts = '/accounts';
}

GoRouter buildRouter({required bool onboardingComplete}) => GoRouter(
  initialLocation: onboardingComplete ? RoutePaths.home : RoutePaths.onboarding,
  routes: [
    GoRoute(
      name: RouteNames.home,
      path: RoutePaths.home,
      builder: (_, _) => const AppShell(),
    ),
    GoRoute(
      name: RouteNames.history,
      path: RoutePaths.history,
      builder: (_, _) => const AppShell(initialIndex: 1),
    ),
    GoRoute(
      name: RouteNames.plan,
      path: RoutePaths.plan,
      builder: (_, _) => const AppShell(initialIndex: 2),
    ),
    GoRoute(
      name: RouteNames.goals,
      path: RoutePaths.goals,
      builder: (_, _) => const AppShell(initialIndex: 3),
    ),
    GoRoute(
      name: RouteNames.reports,
      path: RoutePaths.reports,
      builder: (_, _) => const AppShell(initialIndex: 4),
    ),
    GoRoute(
      name: RouteNames.onboarding,
      path: RoutePaths.onboarding,
      builder: (_, _) => const OnboardingScreen(),
    ),
    GoRoute(
      name: RouteNames.settings,
      path: RoutePaths.settings,
      builder: (_, _) => const SettingsScreen(),
    ),
    GoRoute(
      name: RouteNames.accounts,
      path: RoutePaths.accounts,
      builder: (_, _) => const AccountsScreen(),
    ),
  ],
);
