import 'package:flutter/material.dart';
import '../../../core/theme/velora_tokens.dart';
import '../onboarding_controller.dart';
import '../onboarding_step.dart';

class PeriodStep extends OnboardingStep {
  @override
  String get id => 'period';
  @override
  String get title => 'Davr sozlamalari';
  @override
  String get lead =>
      'Moliyaviy oyingiz va haftangiz qachon boshlanishini tanlang.';

  static const _weekdayNames = [
    'Dushanba',
    'Seshanba',
    'Chorshanba',
    'Payshanba',
    'Juma',
    'Shanba',
    'Yakshanba',
  ];

  @override
  Widget build(BuildContext context, OnboardingController controller) =>
      OnboardingStepScaffold(
        title: title,
        lead: lead,
        children: [
          OnboardingFieldTile(
            label: 'Oy davrining boshlanish kuni',
            child: DropdownButton<int>(
              value: controller.state.settings.periodStartDay,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                for (var day = 1; day <= 31; day++)
                  DropdownMenuItem(value: day, child: Text('$day')),
              ],
              onChanged: (day) {
                if (day == null) return;
                controller.update((s) => s.copyWith(periodStartDay: day));
              },
            ),
          ),
          const SizedBox(height: VeloraSpacing.md),
          OnboardingFieldTile(
            label: 'Hafta boshlanish kuni',
            child: DropdownButton<int>(
              value: controller.state.settings.weekStartIso,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                for (var i = 0; i < _weekdayNames.length; i++)
                  DropdownMenuItem(
                    value: i + 1,
                    child: Text(_weekdayNames[i]),
                  ),
              ],
              onChanged: (iso) {
                if (iso == null) return;
                controller.update((s) => s.copyWith(weekStartIso: iso));
              },
            ),
          ),
        ],
      );
}
