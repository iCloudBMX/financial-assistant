import 'package:go_router/go_router.dart';
import '../accounts/accounts_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../settings/settings_screen.dart';
import 'app_shell.dart';

class RouteNames {
  const RouteNames._();
  static const home = '/';
  static const onboarding = '/onboarding';
  static const settings = '/settings';
  static const accounts = '/accounts';
}

GoRouter buildRouter({required bool onboardingComplete}) => GoRouter(
      initialLocation:
          onboardingComplete ? RouteNames.home : RouteNames.onboarding,
      routes: [
        GoRoute(
            path: RouteNames.home, builder: (_, _) => const AppShell()),
        GoRoute(
            path: RouteNames.onboarding,
            builder: (_, _) => const OnboardingScreen()),
        GoRoute(
            path: RouteNames.settings,
            builder: (_, _) => const SettingsScreen()),
        GoRoute(
            path: RouteNames.accounts,
            builder: (_, _) => const AccountsScreen()),
      ],
    );
