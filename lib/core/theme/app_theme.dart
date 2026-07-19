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
    materialTapTargetSize: MaterialTapTargetSize.padded,
    chipTheme: _veloraChipTheme,
    segmentedButtonTheme: _veloraSegmentedButtonTheme,
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
    materialTapTargetSize: MaterialTapTargetSize.padded,
    chipTheme: _veloraChipTheme,
    segmentedButtonTheme: _veloraSegmentedButtonTheme,
  );
}

/// Chips (income-type, account-type selectors) default to a ~32dp visual
/// height; combined with the theme-level `MaterialTapTargetSize.padded`, this
/// padding keeps them comfortably within the 48×48 accessibility minimum.
const ChipThemeData _veloraChipTheme = ChipThemeData(
  padding: EdgeInsets.symmetric(
    horizontal: VeloraSpacing.md,
    vertical: VeloraSpacing.sm,
  ),
);

/// Segmented buttons (income interval kind) are pinned to a 48dp minimum
/// height so every segment is comfortably tappable.
const SegmentedButtonThemeData _veloraSegmentedButtonTheme =
    SegmentedButtonThemeData(
  style: ButtonStyle(
    tapTargetSize: MaterialTapTargetSize.padded,
    minimumSize: WidgetStatePropertyAll(Size(0, 48)),
  ),
);
