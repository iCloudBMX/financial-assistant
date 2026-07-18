import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/theme/app_colors.dart';
import 'package:financial_assistant/core/theme/app_theme.dart';

void main() {
  test('light and dark themes use Material 3', () {
    expect(buildLightTheme().useMaterial3, isTrue);
    expect(buildDarkTheme().colorScheme.brightness, Brightness.dark);
  });

  test('each status style pairs a distinct icon with its color', () {
    final icons = {
      AppStatusStyle.safe.icon,
      AppStatusStyle.near.icon,
      AppStatusStyle.over.icon,
    };
    expect(icons.length, 3); // color is never the only differentiator
  });
}
