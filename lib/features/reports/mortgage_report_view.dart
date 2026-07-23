import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_async_state.dart';
import '../../ui/components/velora_card.dart';

// ponytail: §13.8 month-by-month balance table + estimated-interest-saved/
// term-reduction are DEFERRED — the amortization loop keeps no schedule and
// interest-saved needs a scenario baseline. Summary figures below are all
// already computed on MortgageWithProjection. Add the schedule table + a
// scenario compare when a mortgage-detail report is requested.

/// The Ipoteka (mortgage) report tab (§13.8): re-surfaces each mortgage's
/// already-computed [MortgageWithProjection] (from `mortgagesProvider`) as a
/// read-only list of cards.
class MortgageReportView extends ConsumerWidget {
  const MortgageReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mortgages = ref.watch(mortgagesProvider);
    return mortgages.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => VeloraErrorState(
        message: 'Xatolik yuz berdi',
        onRetry: () => ref.invalidate(mortgagesProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const VeloraEmptyState(
            icon: Icons.account_balance_outlined,
            title: "Ipoteka qo'shilmagan",
            message: "Ipoteka qo'shilgach, shu yerda hisobot ko'rinadi.",
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in list) ...[
              _MortgageReportCard(item: item),
              const SizedBox(height: VeloraSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _MortgageReportCard extends StatelessWidget {
  const _MortgageReportCard({required this.item});

  final MortgageWithProjection item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = CurrencyRegistry.byCode(item.mortgage.currencyCode);
    Money money(int v) => Money(v, currency);
    final completion = (item.completionBp / 100).clamp(0, 100).toStringAsFixed(0);
    // Every payoff date is an estimate (§6.9) — never presented as an exact
    // bank figure.
    final payoffLabel = item.projection.neverCloses
        ? "Joriy to'lovda hech qachon yopilmaydi"
        : (item.projection.payoffDate?.toString().split(' ').first ?? '—');

    return VeloraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.mortgage.name,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: VeloraSpacing.md),
          _row(context, 'Qolgan asosiy qarz', money(item.currentPrincipalMinor).format()),
          _row(context, "To'langan asosiy qarz", money(item.totals.principalPaidMinor).format()),
          _row(context, "To'langan foiz", money(item.totals.interestPaidMinor).format()),
          _row(context, "Qo'shimcha to'lovlar", money(item.totals.extraPaidMinor).format()),
          _row(context, 'Yopilgan qismi', '$completion%'),
          _row(context, 'Rejalashtirilgan yopilish sanasi', payoffLabel),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: VeloraSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: VeloraSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
