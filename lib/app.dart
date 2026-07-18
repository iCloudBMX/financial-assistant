import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/settings/settings_model.dart';
import 'features/security/app_lock_gate.dart';
import 'features/security/background_shield.dart';
import 'features/shell/routes.dart';
import 'providers/app_providers.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(metaProvider);
    final settings = ref.watch(settingsProvider);

    return meta.when(
      loading: () => const _Bootstrapping(),
      error: (_, _) => const _Bootstrapping(),
      // Settings is nested inside meta's data branch (rather than read via
      // `maybeWhen(orElse: () => false)` alongside it) so the router never
      // renders while settings is still loading. Both providers read from
      // the same serial Drift connection and resolve independently; without
      // this nesting there is a window where `meta` has data (dismissing
      // `_Bootstrapping`) but `settings` is still `AsyncLoading`, during
      // which appLockEnabled/biometricEnabled would silently default to
      // `false` and the app would render without AppLockGate even for a
      // returning user who enabled app-lock.
      data: (m) => settings.when(
        loading: () => const _Bootstrapping(),
        error: (_, _) => const _Bootstrapping(),
        data: (s) {
          final themeMode = switch (s.themeMode) {
            ThemeModeSetting.system => ThemeMode.system,
            ThemeModeSetting.light => ThemeMode.light,
            ThemeModeSetting.dark => ThemeMode.dark,
          };
          final appLockEnabled = s.appLockEnabled;
          final biometricEnabled = s.biometricEnabled;

          return MaterialApp.router(
            title: 'Moliyaviy Assistent',
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: themeMode,
            routerConfig:
                buildRouter(onboardingComplete: m.onboardingComplete),
            // BackgroundShield/AppLockGate are wired inside `builder`
            // (rather than wrapping MaterialApp.router itself) so both sit
            // inside the Directionality/Localizations/MediaQuery that
            // MaterialApp establishes -- BackgroundShield's Stack needs a
            // Directionality ancestor to resolve its default
            // AlignmentDirectional, which doesn't exist above MaterialApp.
            //
            // When app-lock is enabled, AppLockGate discards `child` (the
            // router/Navigator) while locked, which also discards the
            // Overlay the Navigator normally supplies -- and the lock
            // screen's PIN TextField needs an Overlay ancestor for its
            // selection handles. Wrap that branch in its own Overlay so the
            // lock screen doesn't depend on the (possibly-unmounted) router
            // for one.
            builder: (context, child) {
              final router = child ?? const SizedBox.shrink();
              if (!appLockEnabled) {
                return BackgroundShield(child: router);
              }
              return Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => BackgroundShield(
                      child: AppLockGate(
                        controller: ref.watch(appLockControllerProvider),
                        enabled: true,
                        biometricEnabled: biometricEnabled,
                        child: router,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Bootstrapping extends StatelessWidget {
  const _Bootstrapping();
  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
}
