import 'package:flutter/material.dart';
import '../../../core/money/currency.dart';
import '../onboarding_controller.dart';
import '../onboarding_step.dart';

class CurrencyStep extends OnboardingStep {
  @override
  String get id => 'currency';
  @override
  String get title => 'Asosiy valyuta';

  static const _currencies = [
    CurrencyRegistry.uzs,
    CurrencyRegistry.usd,
    CurrencyRegistry.eur,
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
            DropdownButton<String>(
              value: controller.state.settings.primaryCurrency.code,
              items: [
                for (final c in _currencies)
                  DropdownMenuItem(value: c.code, child: Text(c.code)),
              ],
              onChanged: (code) {
                if (code == null) return;
                controller.update(
                  (s) => s.copyWith(
                    primaryCurrency: CurrencyRegistry.byCode(code),
                  ),
                );
              },
            ),
          ],
        ),
      );
}
