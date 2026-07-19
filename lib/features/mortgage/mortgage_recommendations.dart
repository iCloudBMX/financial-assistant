import 'package:flutter/material.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/mortgage/mortgage_engine.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_card.dart';

/// Informational recommendation cards (§13.7 thin subset): payoff at the
/// current rate, and the effect of a sample monthly extra payment. These are
/// advisory only — the mandated disclaimer is always shown alongside them.
///
/// Deferred (need allocation-preview / negative-freeBalance signals not yet
/// available here): undistributed-funds and minimum-reserve recommendations.
class MortgageRecommendations extends StatelessWidget {
  final MortgageWithProjection item;
  const MortgageRecommendations({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final cur = CurrencyRegistry.byCode(item.mortgage.currencyCode);
    final payoff = item.projection.neverCloses
        ? 'joriy to\'lovda yopilmaydi'
        : (item.projection.payoffDate?.toString().split(' ').first ?? '—');
    final sampleExtra = item.mortgage.mandatoryPaymentMinor ~/ 10;
    final withExtra = computeScenario(
      kind: ScenarioKind.fixedExtraMonthly,
      currentPrincipalMinor: item.currentPrincipalMinor,
      annualRateBp: item.mortgage.annualRateBp,
      type: item.mortgage.paymentType,
      monthlyPaymentMinor: item.mortgage.mandatoryPaymentMinor,
      monthlyPrincipalMinor: item.monthlyPrincipalMinor,
      extraMonthlyMinor: sampleExtra,
      asOf: DateTime.now(),
    );
    return VeloraCard(
      key: const Key('mortgage-recommendations'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Taxminiy tavsiyalar',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: VeloraSpacing.sm),
          Text('Joriy sur\'atda ipoteka taxminan $payoff yopiladi.'),
          const SizedBox(height: VeloraSpacing.xs),
          Text('Oyiga ${Money(sampleExtra, cur).format()} qo\'shsangiz, '
              'taxminan ${withExtra.monthsSaved} oy tejaysiz '
              '(${Money(withExtra.interestSavedMinor, cur).format()} foiz).'),
          const SizedBox(height: VeloraSpacing.sm),
          Text(
            'Tavsiyalar axborot xarakterida va bankning rasmiy '
            'hisob-kitobini almashtirmaydi.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
