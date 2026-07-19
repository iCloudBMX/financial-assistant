import 'package:flutter/material.dart';
import '../../core/theme/velora_tokens.dart';
import '../../features/home/dashboard_data.dart';
import '../../ui/components/velora_card.dart';
import 'mortgage_dashboard_screen.dart';

/// The Home mortgage summary (§6.2 step 6, second half). A pure value widget
/// over the resolved [summary] that `dashboardProvider` folded into
/// `DashboardData`; a null [summary] renders the reachable "add mortgage"
/// CTA. Both states tap into the mortgage dashboard.
class MortgageSummaryCard extends StatelessWidget {
  const MortgageSummaryCard({super.key, required this.summary});

  final MortgageSummaryView? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    void open() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MortgageDashboardScreen()));

    final m = summary;
    if (m == null) {
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
          Text('${m.name} • ${m.currentPrincipal.format()}'),
          Text('Navbatdagi to\'lov: ${m.nextPaymentAmount.format()}'
              ' (${m.nextPaymentDate.toString().split(' ').first})'),
        ],
      ),
    );
  }
}
