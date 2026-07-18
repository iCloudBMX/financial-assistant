import 'package:flutter/material.dart';
import '../onboarding_controller.dart';
import '../onboarding_step.dart';

class PeriodStep extends OnboardingStep {
  @override
  String get id => 'period';
  @override
  String get title => 'Davr sozlamalari';

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
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text("Oy davrining boshlanish kuni",
                style: Theme.of(context).textTheme.bodyMedium),
            DropdownButton<int>(
              value: controller.state.settings.periodStartDay,
              items: [
                for (var day = 1; day <= 31; day++)
                  DropdownMenuItem(value: day, child: Text('$day')),
              ],
              onChanged: (day) {
                if (day == null) return;
                controller
                    .update((s) => s.copyWith(periodStartDay: day));
              },
            ),
            const SizedBox(height: 16),
            Text('Hafta boshlanish kuni',
                style: Theme.of(context).textTheme.bodyMedium),
            DropdownButton<int>(
              value: controller.state.settings.weekStartIso,
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
          ],
        ),
      );
}
