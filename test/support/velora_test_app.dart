import 'package:financial_assistant/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

bool _fontsLoaded = false;

/// Pumps [child] inside the Velora theme/MediaQuery harness used by every
/// golden test.
///
/// [container]: pass a [ProviderContainer] when the pumped screen will push
/// a NEW route on top of itself (a `showModalBottomSheet`/`showDialog`
/// trigger) -- e.g. the existing-flow gallery's sheet/dialog goldens. Riverpod
/// resolves `ProviderScope`/`UncontrolledProviderScope` per-route: a scope
/// wrapping only `home` is an ancestor of the first route's content, but NOT
/// of a route pushed later on the same `Navigator` (each route's content is
/// a sibling `OverlayEntry`, not a descendant of the previous route's
/// widgets). A widget in that later route calling `ref.watch`/`ref.read`
/// then fails with "Bad state: No ProviderScope found". Passing [container]
/// wraps the whole `MaterialApp` (so its `Navigator`, and every route pushed
/// on it) in one scope instead. Golden tests that render a screen directly
/// with no further navigation (the common case) don't need this -- they can
/// keep wrapping `child` in `UncontrolledProviderScope` themselves, as
/// before.
///
/// [settle]: set to `false` for a "loading" golden whose UI includes an
/// indeterminate `CircularProgressIndicator` (or any other non-stopping
/// animation) -- `pumpAndSettle` waits for scheduled frames to stop, which
/// an indeterminate spinner never does, so it always times out. `settle:
/// false` pumps a single settled-enough frame instead.
Future<void> pumpVelora(
  WidgetTester tester, {
  required Widget child,
  required Size size,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  ProviderContainer? container,
  bool settle = true,
}) async {
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await _loadBundledFonts();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;

  final app = MaterialApp(
    key: ValueKey((brightness, textScale, size)),
    debugShowCheckedModeBanner: false,
    theme: buildLightTheme(),
    darkTheme: buildDarkTheme(),
    themeAnimationDuration: Duration.zero,
    themeMode:
        brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, appChild) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: true,
        textScaler: TextScaler.linear(textScale),
      ),
      child: appChild!,
    ),
    home: child,
  );

  await tester.pumpWidget(
    container == null
        ? app
        : UncontrolledProviderScope(container: container, child: app),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // One frame plus a microtask flush -- enough for the initial
    // AsyncLoading frame to render without waiting for an animation
    // (the spinner) that never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _loadBundledFonts() async {
  if (_fontsLoaded) return;

  await Future.wait([
    (FontLoader(
      'Onest',
    )..addFont(rootBundle.load('assets/fonts/Onest-Variable.ttf'))).load(),
    (FontLoader(
      'NotoSans',
    )..addFont(rootBundle.load('assets/fonts/NotoSans-Variable.ttf'))).load(),
    (FontLoader(
      'IBMPlexMono',
    )..addFont(rootBundle.load('assets/fonts/IBMPlexMono-Regular.ttf'))).load(),
    (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load(),
  ]);
  _fontsLoaded = true;
}
