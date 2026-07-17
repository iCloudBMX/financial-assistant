import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.warmPrimary,
    brightness: Brightness.light,
    error: AppColors.error,
    surface: AppColors.surfaceLight,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: buildTextTheme(scheme),
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.warmPrimary,
    brightness: Brightness.dark,
    error: AppColors.error,
    surface: AppColors.surfaceDark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: buildTextTheme(scheme),
  );
}
