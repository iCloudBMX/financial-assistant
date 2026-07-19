import 'package:flutter/material.dart';

TextTheme buildTextTheme(ColorScheme scheme) {
  final typography = Typography.material2021(platform: TargetPlatform.android);
  final base = scheme.brightness == Brightness.dark
      ? typography.white
      : typography.black;
  final interface = base.apply(
    fontFamily: 'NotoSans',
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  TextStyle? heading(TextStyle? style) => style?.copyWith(fontFamily: 'Onest');

  return interface.copyWith(
    displayLarge: heading(interface.displayLarge),
    displayMedium: heading(interface.displayMedium),
    displaySmall: heading(interface.displaySmall),
    headlineLarge: heading(interface.headlineLarge),
    headlineMedium: heading(interface.headlineMedium),
    headlineSmall: heading(interface.headlineSmall),
    titleLarge: heading(interface.titleLarge),
    titleMedium: heading(interface.titleMedium),
    titleSmall: heading(interface.titleSmall),
  );
}
