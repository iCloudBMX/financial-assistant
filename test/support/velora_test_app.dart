import 'package:financial_assistant/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool _fontsLoaded = false;

Future<void> pumpVelora(
  WidgetTester tester, {
  required Widget child,
  required Size size,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await _loadBundledFonts();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;

  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey((brightness, textScale, size)),
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeAnimationDuration: Duration.zero,
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      builder: (context, appChild) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: appChild!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
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
