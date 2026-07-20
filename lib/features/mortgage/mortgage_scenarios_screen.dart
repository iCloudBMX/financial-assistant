import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/mortgage/mortgage_engine.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_card.dart';

// ~88px clears the global floating "Chiqim" FAB below the last card.
const _fabClearance = 88.0;

class MortgageScenariosScreen extends ConsumerWidget {
  final int mortgageId;
  const MortgageScenariosScreen({super.key, required this.mortgageId});

  static const _labels = {
    ScenarioKind.mandatoryOnly: 'Faqat majburiy to\'lov',
    ScenarioKind.fixedExtraMonthly: 'Har oy qo\'shimcha',
    ScenarioKind.oneTimeExtra: 'Bir martalik qo\'shimcha',
    ScenarioKind.allRemainingIncome: 'Qolgan mablag\'ni to\'lash',
  };

  static const _tags = {
    ScenarioKind.mandatoryOnly: 'Baza',
    ScenarioKind.fixedExtraMonthly: 'Eng maqbul',
    ScenarioKind.oneTimeExtra: 'Bir marta',
    ScenarioKind.allRemainingIncome: 'Dinamik',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(mortgagesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ssenariylar')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Xatolik yuz berdi')),
        data: (list) {
          MortgageWithProjection? item;
          for (final e in list) {
            if (e.mortgage.id == mortgageId) {
              item = e;
              break;
            }
          }
          if (item == null) return const Center(child: Text('Topilmadi'));
          final cur = CurrencyRegistry.byCode(item.mortgage.currencyCode);
          final mandatory = item.mortgage.mandatoryPaymentMinor;
          final sample = mandatory ~/ 10; // 10% sample extra
          final scenarios = compareScenarios(
            currentPrincipalMinor: item.currentPrincipalMinor,
            annualRateBp: item.mortgage.annualRateBp,
            type: item.mortgage.paymentType,
            monthlyPaymentMinor: mandatory,
            monthlyPrincipalMinor: item.monthlyPrincipalMinor,
            extraMonthlyMinor: sample,
            oneTimeExtraMinor: mandatory,
            remainingIncomeMinor: sample * 2,
            asOf: DateTime.now(),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              VeloraSpacing.lg,
              VeloraSpacing.lg,
              VeloraSpacing.lg,
              _fabClearance,
            ),
            children: [
              // §6.9: every scenario figure is a projection, not a bank
              // statement — the "Taxminiy" (estimate) tag applies to all
              // four rows below, not only the ones flagged approximate.
              Text('Taxminiy natijalar', style: theme.textTheme.titleMedium),
              const SizedBox(height: VeloraSpacing.xs),
              Text(
                'Har bir ssenariy taxminiy hisob-kitob; bankning rasmiy '
                'jadvalini almashtirmaydi.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: VeloraColors.muted),
              ),
              const SizedBox(height: VeloraSpacing.md),
              for (final s in scenarios) ...[
                VeloraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(_labels[s.kind]!,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: VeloraSpacing.sm),
                          _Tag(
                            label: _tags[s.kind]!,
                            highlight: s.kind == ScenarioKind.fixedExtraMonthly,
                          ),
                        ],
                      ),
                      const SizedBox(height: VeloraSpacing.md),
                      if (s.neverCloses)
                        Text('Yopilmaydi',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: VeloraColors.muted))
                      else
                        _ScenarioStats(scenario: s, currency: cur),
                      if (s.isApproximate) ...[
                        const SizedBox(height: VeloraSpacing.sm),
                        Text('(taxminiy hisob-kitob)',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: VeloraColors.muted)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: VeloraSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The three-up figure strip inside a scenario card. The middle/last columns
/// shift with the scenario kind so the most relevant number leads.
class _ScenarioStats extends StatelessWidget {
  const _ScenarioStats({required this.scenario, required this.currency});

  final ScenarioResult scenario;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final s = scenario;
    final payoff = s.payoffDate?.toString().split(' ').first ?? '—';
    Money m(int v) => Money(v, currency);

    final (String midLabel, String midValue) =
        s.kind == ScenarioKind.mandatoryOnly
            ? ('Qolgan', '${s.monthsRemaining} oy')
            : ('Tejaladi', '${s.monthsSaved} oy');
    final (String lastLabel, String lastValue) = switch (s.kind) {
      ScenarioKind.mandatoryOnly => ('Jami foiz', m(s.totalInterestMinor).formatNumber()),
      ScenarioKind.allRemainingIncome => ('Oylik', m(s.requiredMonthlyMinor).formatNumber()),
      _ => ('Foiz tejaladi', m(s.interestSavedMinor).formatNumber()),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _Stat(label: 'Yopilish', value: payoff)),
          const SizedBox(width: VeloraSpacing.sm),
          Expanded(child: _Stat(label: midLabel, value: midValue)),
          const SizedBox(width: VeloraSpacing.sm),
          Expanded(child: _Stat(label: lastLabel, value: lastValue)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style:
                theme.textTheme.labelSmall?.copyWith(color: VeloraColors.muted)),
        const SizedBox(height: VeloraSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// The scenario's short kind tag; the best scenario gets the apricot highlight.
class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.highlight});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VeloraSpacing.sm,
        vertical: VeloraSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: highlight ? VeloraColors.apricot : VeloraColors.plumTint,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: highlight ? VeloraColors.inkberry : VeloraColors.plum,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
