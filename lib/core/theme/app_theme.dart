import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'velora_tokens.dart';

ThemeData buildLightTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: VeloraColors.plum,
        brightness: Brightness.light,
      ).copyWith(
        primary: VeloraColors.plum,
        secondary: VeloraColors.coral,
        surface: VeloraColors.blush,
        error: VeloraColors.critical,
        onSurface: VeloraColors.inkberry,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: VeloraColors.blush,
    textTheme: buildTextTheme(scheme),
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: VeloraColors.plum,
    brightness: Brightness.dark,
  ).copyWith(secondary: VeloraColors.coral, error: VeloraColors.critical);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: buildTextTheme(scheme),
  );
}
