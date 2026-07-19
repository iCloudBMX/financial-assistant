import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_card.dart';
import 'mortgage_dashboard_screen.dart';

/// The Home mortgage summary (§6.2 step 6, second half). Self-driven by
/// `mortgagesProvider` — a provider, not a raw repository — so it stays
/// reusable outside Home (e.g. its own widget test) without threading
/// `DashboardData` through it.
class MortgageSummaryCard extends ConsumerWidget {
  const MortgageSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mortgagesProvider);
    final theme = Theme.of(context);
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (list) {
        void open() => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const MortgageDashboardScreen()));
        if (list.isEmpty) {
          return VeloraCard(
            key: const Key('mortgage-summary-card'),
            onTap: open,
            child: Row(
              children: [
                Icon(Icons.account_balance, color: theme.colorScheme.primary),
                const SizedBox(width: VeloraSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ipoteka', style: theme.textTheme.titleMedium),
                      const SizedBox(height: VeloraSpacing.xs),
                      const Text('Ipoteka qo\'shish'),
                    ],
                  ),
                ),
                const Icon(Icons.add),
              ],
            ),
          );
        }
        final m = list.first;
        final cur = CurrencyRegistry.byCode(m.mortgage.currencyCode);
        return VeloraCard(
          key: const Key('mortgage-summary-card'),
          onTap: open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Ipoteka', style: theme.textTheme.titleMedium),
                  ),
                  Text('${(m.completionBp / 100).toStringAsFixed(0)}%'),
                ],
              ),
              const SizedBox(height: VeloraSpacing.xs),
              Text(
                  '${m.mortgage.name} • ${Money(m.currentPrincipalMinor, cur).format()}'),
              Text(
                  'Navbatdagi to\'lov: ${Money(m.mortgage.mandatoryPaymentMinor, cur).format()}'
                  ' (${m.mortgage.nextPaymentDate.toString().split(' ').first})'),
            ],
          ),
        );
      },
    );
  }
}
