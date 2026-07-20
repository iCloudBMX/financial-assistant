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
    navigationBarTheme: _veloraNavBarTheme(VeloraColors.plumTint),
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
    navigationBarTheme:
        _veloraNavBarTheme(scheme.surfaceContainerHigh),
  );
}

/// The bottom navigation, styled to the approved mockup: a soft tinted bar
/// with a plum "pill" indicator behind the selected destination's icon,
/// white-on-plum when active and muted when not. Kept as a themed Material
/// `NavigationBar` (not a bespoke widget) so the shell's navigation and
/// lock-state contracts that assert on `NavigationBar` keep holding.
NavigationBarThemeData _veloraNavBarTheme(Color background) {
  return NavigationBarThemeData(
    backgroundColor: background,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    height: 68,
    indicatorColor: VeloraColors.plum,
    indicatorShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(VeloraRadii.control),
    ),
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? const IconThemeData(color: Colors.white, size: 22)
          : const IconThemeData(color: VeloraColors.muted, size: 22),
    ),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: states.contains(WidgetState.selected)
            ? VeloraColors.plum
            : VeloraColors.muted,
      ),
    ),
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
