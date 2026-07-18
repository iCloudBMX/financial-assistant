import 'package:flutter/material.dart';
import '../../../core/money/money.dart';
import '../onboarding_controller.dart';
import '../onboarding_step.dart';

class ReserveStep extends OnboardingStep {
  @override
  String get id => 'reserve';
  @override
  String get title => 'Minimal zaxira';

  @override
  Widget build(BuildContext context, OnboardingController controller) =>
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Summa'),
              onChanged: (t) {
                final m = Money.tryParse(
                    t, controller.state.settings.primaryCurrency);
                if (m != null) {
                  controller.update((s) => s.copyWith(minReserve: m));
                }
              },
            ),
          ],
        ),
      );
}
