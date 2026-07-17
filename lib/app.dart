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
      data: (m) {
        final themeMode = settings.maybeWhen(
          data: (s) => switch (s.themeMode) {
            ThemeModeSetting.system => ThemeMode.system,
            ThemeModeSetting.light => ThemeMode.light,
            ThemeModeSetting.dark => ThemeMode.dark,
          },
          orElse: () => ThemeMode.system,
        );
        final appLockEnabled = settings.maybeWhen(
          data: (s) => s.appLockEnabled,
          orElse: () => false,
        );
        final biometricEnabled = settings.maybeWhen(
          data: (s) => s.biometricEnabled,
          orElse: () => false,
        );

        return MaterialApp.router(
          title: 'Moliyaviy Assistent',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: themeMode,
          routerConfig: buildRouter(onboardingComplete: m.onboardingComplete),
          // BackgroundShield/AppLockGate are wired inside `builder` (rather
          // than wrapping MaterialApp.router itself) so both sit inside the
          // Directionality/Localizations/MediaQuery that MaterialApp
          // establishes -- BackgroundShield's Stack needs a Directionality
          // ancestor to resolve its default AlignmentDirectional, which
          // doesn't exist above MaterialApp.
          //
          // When app-lock is enabled, AppLockGate discards `child` (the
          // router/Navigator) while locked, which also discards the Overlay
          // the Navigator normally supplies -- and the lock screen's PIN
          // TextField needs an Overlay ancestor for its selection handles.
          // Wrap that branch in its own Overlay so the lock screen doesn't
          // depend on the (possibly-unmounted) router for one.
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
