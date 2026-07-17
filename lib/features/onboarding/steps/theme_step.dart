import 'package:flutter/material.dart';
import '../../../data/settings/settings_model.dart';
import '../onboarding_controller.dart';
import '../onboarding_step.dart';

class ThemeStep extends OnboardingStep {
  @override
  String get id => 'theme';
  @override
  String get title => 'Mavzu';

  static const _labels = {
    ThemeModeSetting.system: 'Tizim',
    ThemeModeSetting.light: 'Yorug\'',
    ThemeModeSetting.dark: 'Qorong\'i',
  };

  @override
  Widget build(BuildContext context, OnboardingController controller) =>
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            SegmentedButton<ThemeModeSetting>(
              segments: [
                for (final mode in ThemeModeSetting.values)
                  ButtonSegment(value: mode, label: Text(_labels[mode]!)),
              ],
              selected: {controller.state.settings.themeMode},
              onSelectionChanged: (selection) {
                controller.update(
                  (s) => s.copyWith(themeMode: selection.first),
                );
              },
            ),
          ],
        ),
      );
}
