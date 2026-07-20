import 'package:flutter/material.dart';
import '../../../data/settings/settings_model.dart';
import '../onboarding_controller.dart';
import '../onboarding_step.dart';

class ThemeStep extends OnboardingStep {
  @override
  String get id => 'theme';
  @override
  String get title => 'Mavzu';
  @override
  String get lead => "Velora'ning ko'rinishini xohlaganingizcha tanlang.";

  static String _labelFor(ThemeModeSetting mode) => switch (mode) {
        ThemeModeSetting.system => 'Tizim',
        ThemeModeSetting.light => 'Yorug\'',
        ThemeModeSetting.dark => 'Qorong\'i',
      };

  @override
  Widget build(BuildContext context, OnboardingController controller) =>
      OnboardingStepScaffold(
        title: title,
        lead: lead,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<ThemeModeSetting>(
              segments: [
                for (final mode in ThemeModeSetting.values)
                  ButtonSegment(value: mode, label: Text(_labelFor(mode))),
              ],
              selected: {controller.state.settings.themeMode},
              onSelectionChanged: (selection) {
                controller.update(
                  (s) => s.copyWith(themeMode: selection.first),
                );
              },
            ),
          ),
        ],
      );
}
