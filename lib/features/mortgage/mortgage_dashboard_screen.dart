import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_async_state.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_card.dart';
import 'mortgage_edit_sheet.dart';
import 'mortgage_payment_sheet.dart';
import 'mortgage_extra_payment_sheet.dart';
import 'mortgage_recommendations.dart';
import 'mortgage_scenarios_screen.dart';

class MortgageDashboardScreen extends ConsumerWidget {
  const MortgageDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mortgagesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ipoteka')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => VeloraErrorState(
          message: 'Xatolik yuz berdi',
          onRetry: () => ref.invalidate(mortgagesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return VeloraEmptyState(
              icon: Icons.account_balance_outlined,
              title: 'Ipoteka qo\'shilmagan',
              message: 'Ipotekangizni qo\'shib, to\'lovlarni kuzating.',
              action: VeloraPrimaryButton(
                label: 'Ipoteka qo\'shish',
                onPressed: () => showMortgageEditSheet(context, ref),
              ),
            );
          }
          final m = list.first; // MVP: one primary mortgage on the dashboard
          final cur = CurrencyRegistry.byCode(m.mortgage.currencyCode);
          Money money(int v) => Money(v, cur);
          // Every payoff date is an estimate (§6.9) — never presented as an
          // exact bank figure.
          final payoff = m.projection.neverCloses
              ? 'Joriy to\'lovda yopilmaydi'
              : (m.projection.payoffDate?.toString().split(' ').first ?? '—');
          return ListView(
            padding: const EdgeInsets.all(VeloraSpacing.lg),
            children: [
              Text(m.mortgage.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: VeloraSpacing.md),
              VeloraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _row('Joriy qarz qoldig\'i',
                        money(m.currentPrincipalMinor).format()),
                    _row('Yillik foiz',
                        '${m.mortgage.annualRateBp ~/ 100}.${(m.mortgage.annualRateBp % 100).toString().padLeft(2, '0')}%'),
                    _row('Navbatdagi to\'lov',
                        money(m.mortgage.mandatoryPaymentMinor).format()),
                    _row('Navbatdagi sana',
                        m.mortgage.nextPaymentDate.toString().split(' ').first),
                    const Divider(),
                    _row('Jami to\'langan', money(m.totals.paidMinor).format()),
                    _row('Asosiy qarzga',
                        money(m.totals.principalPaidMinor).format()),
                    _row('Foizga', money(m.totals.interestPaidMinor).format()),
                    _row('Qo\'shimcha to\'lovlar',
                        money(m.totals.extraPaidMinor).format()),
                    const Divider(),
                    _row('Bajarilishi',
                        '${(m.completionBp / 100).toStringAsFixed(1)}%'),
                    _row('Taxminiy yopilish sanasi', payoff),
                  ],
                ),
              ),
              const SizedBox(height: VeloraSpacing.lg),
              MortgageRecommendations(item: m),
              const SizedBox(height: VeloraSpacing.lg),
              Wrap(spacing: VeloraSpacing.sm, runSpacing: VeloraSpacing.sm, children: [
                FilledButton(
                  onPressed: () =>
                      showMortgagePaymentSheet(context, ref, m.mortgage.id),
                  child: const Text('To\'lov kiritish'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      showMortgageExtraPaymentSheet(context, ref, m.mortgage.id),
                  child: const Text('Qo\'shimcha to\'lov'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          MortgageScenariosScreen(mortgageId: m.mortgage.id))),
                  child: const Text('Ssenariylar'),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  // `Expanded`, not a bare `Text`, for the label: at 320px/200% text scale
  // an unwrapped label (e.g. "Taxminiy yopilish sanasi") plus its value can
  // exceed the Row's width on its own -- a plain `Text` can't shrink below
  // its natural single-line width, so only a flexible label lets the Row
  // wrap instead of overflowing (golden-revealed via the existing-flow
  // gallery's 320/dark/200% variant).
  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: VeloraSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: Text(label)),
            const SizedBox(width: VeloraSpacing.sm),
            Expanded(
              flex: 3,
              child: Text(
                value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}
