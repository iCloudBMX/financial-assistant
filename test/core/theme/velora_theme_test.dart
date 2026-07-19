import 'package:financial_assistant/core/theme/app_theme.dart';
import 'package:financial_assistant/core/theme/velora_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Velora light theme maps exact approved semantic colors', () {
    final theme = buildLightTheme();
    expect(theme.colorScheme.primary, const Color(0xFF5B3A6E));
    expect(theme.colorScheme.secondary, const Color(0xFFE96F5C));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFFF8F5));
    expect(theme.textTheme.headlineSmall?.fontFamily, 'Onest');
    expect(theme.textTheme.bodyMedium?.fontFamily, 'NotoSans');
  });

  test('Velora tokens expose the approved foundation values', () {
    expect(VeloraColors.plum, const Color(0xFF5B3A6E));
    expect(VeloraColors.coral, const Color(0xFFE96F5C));
    expect(VeloraColors.apricot, const Color(0xFFFFB46A));
    expect(VeloraColors.blush, const Color(0xFFFFF8F5));
    expect(VeloraColors.inkberry, const Color(0xFF332A3A));
    expect(VeloraColors.success, const Color(0xFF2E9D7C));
    expect(VeloraColors.critical, const Color(0xFFC94E58));
    expect(VeloraSpacing.xs, 4.0);
    expect(VeloraSpacing.sm, 8.0);
    expect(VeloraSpacing.md, 12.0);
    expect(VeloraSpacing.lg, 16.0);
    expect(VeloraSpacing.xl, 24.0);
    expect(VeloraRadii.control, 16.0);
    expect(VeloraRadii.card, 22.0);
    expect(VeloraRadii.sheet, 28.0);
    expect(VeloraMotion.standard, const Duration(milliseconds: 200));
  });

  test('Velora statuses pair semantic colors with icons and labels', () {
    expect(VeloraStatus.safe.color, VeloraColors.success);
    expect(VeloraStatus.safe.icon, Icons.check_circle);
    expect(VeloraStatus.safe.labelKey, 'status_safe');
    expect(VeloraStatus.near.color, VeloraColors.apricot);
    expect(VeloraStatus.near.icon, Icons.info);
    expect(VeloraStatus.near.labelKey, 'status_near');
    expect(VeloraStatus.over.color, VeloraColors.critical);
    expect(VeloraStatus.over.icon, Icons.warning_amber);
    expect(VeloraStatus.over.labelKey, 'status_over');
  });
}
