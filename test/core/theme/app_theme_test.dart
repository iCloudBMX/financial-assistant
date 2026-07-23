import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/theme/app_theme.dart';
import 'package:financial_assistant/core/theme/velora_tokens.dart';

void main() {
  test('light and dark themes use Material 3', () {
    expect(buildLightTheme().useMaterial3, isTrue);
    expect(buildDarkTheme().colorScheme.brightness, Brightness.dark);
  });

  test('each status style pairs a distinct icon with its color', () {
    final icons = {
      VeloraStatus.safe.icon,
      VeloraStatus.near.icon,
      VeloraStatus.over.icon,
    };
    expect(icons.length, 3); // color is never the only differentiator
  });
}
