import 'package:flutter/material.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/mortgage/mortgage_engine.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';

/// Informational recommendation cards (§13.7 thin subset): payoff at the
/// current rate, and the effect of a sample monthly extra payment. These are
/// advisory only — the mandated disclaimer is always shown alongside them.
///
/// Styled as the mockup's soft "recommend" surface (a success-tinted card with
/// a lightbulb tile) so the advice reads as a helpful nudge, not a bank figure.
///
/// Deferred (need allocation-preview / negative-freeBalance signals not yet
/// available here): undistributed-funds and minimum-reserve recommendations.
class MortgageRecommendations extends StatelessWidget {
  final MortgageWithProjection item;
  const MortgageRecommendations({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
    return Container(
      key: const Key('mortgage-recommendations'),
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      decoration: BoxDecoration(
        color: VeloraColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(VeloraRadii.card),
        border: Border.all(color: VeloraColors.success.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: VeloraColors.success,
                  borderRadius: BorderRadius.circular(VeloraRadii.control),
                ),
                child: const Icon(Icons.lightbulb_outline,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: VeloraSpacing.md),
              Expanded(
                child: Text(
                  'Taxminiy tavsiyalar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: VeloraColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.md),
          Text('Joriy sur\'atda ipoteka taxminan $payoff yopiladi.',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: VeloraSpacing.xs),
          Text(
            'Oyiga ${Money(sampleExtra, cur).format()} qo\'shsangiz, '
            'taxminan ${withExtra.monthsSaved} oy tejaysiz '
            '(${Money(withExtra.interestSavedMinor, cur).format()} foiz).',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: VeloraSpacing.sm),
          Text(
            'Tavsiyalar axborot xarakterida va bankning rasmiy '
            'hisob-kitobini almashtirmaydi.',
            style:
                theme.textTheme.bodySmall?.copyWith(color: VeloraColors.muted),
          ),
        ],
      ),
    );
  }
}
