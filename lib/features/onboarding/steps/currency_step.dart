import 'package:flutter/material.dart';
import '../../../core/money/currency.dart';
import '../onboarding_controller.dart';
import '../onboarding_step.dart';

class CurrencyStep extends OnboardingStep {
  @override
  String get id => 'currency';
  @override
  String get title => 'Asosiy valyuta';
  @override
  String get lead =>
      'Asosiy valyuta hisobot va xavfsiz limit hisoblash uchun ishlatiladi.';

  static const _currencies = [
    CurrencyRegistry.uzs,
    CurrencyRegistry.usd,
    CurrencyRegistry.eur,
  ];

  @override
  Widget build(BuildContext context, OnboardingController controller) =>
      OnboardingStepScaffold(
        title: title,
        lead: lead,
        children: [
          OnboardingFieldTile(
            label: 'Valyuta',
            child: DropdownButton<String>(
              value: controller.state.settings.primaryCurrency.code,
              isExpanded: true,
              underline: const SizedBox.shrink(),
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
          ),
        ],
      );
}
