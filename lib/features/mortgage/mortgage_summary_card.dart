import 'package:flutter/material.dart';
import '../../core/theme/velora_tokens.dart';
import '../../features/home/dashboard_data.dart';
import 'mortgage_dashboard_screen.dart';

/// The Home mortgage summary (§6.2 step 6, second half). A pure value widget
/// over the resolved [summary] that `dashboardProvider` folded into
/// `DashboardData`; a null [summary] renders the reachable "add mortgage"
/// CTA. Both states tap into the mortgage dashboard. Styled with the soft
/// plum tint from the approved mockup so it reads as a Velora surface.
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
      return _Shell(
        onTap: open,
        child: Row(
          children: [
            const _IconTile(child: Icon(Icons.account_balance,
                color: Colors.white, size: 20)),
            const SizedBox(width: VeloraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ipoteka', style: theme.textTheme.titleMedium),
                  const SizedBox(height: VeloraSpacing.xs),
                  Text('Ipoteka qo\'shish',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: VeloraColors.muted)),
                ],
              ),
            ),
            const Icon(Icons.add, color: VeloraColors.plum),
          ],
        ),
      );
    }
    return _Shell(
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconTile(child: Icon(Icons.account_balance,
                  color: Colors.white, size: 20)),
              const SizedBox(width: VeloraSpacing.md),
              Expanded(
                child: Text('Ipoteka',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Text('${(m.completionBp / 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: VeloraColors.plum)),
            ],
          ),
          const SizedBox(height: VeloraSpacing.sm),
          Text('${m.name} • ${m.currentPrincipal.format()}',
              style: theme.textTheme.bodySmall),
          Text(
            'Navbatdagi to\'lov: ${m.nextPaymentAmount.format()}'
            ' (${m.nextPaymentDate.toString().split(' ').first})',
            style:
                theme.textTheme.bodySmall?.copyWith(color: VeloraColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(VeloraRadii.card);
    return Material(
      color: VeloraColors.plumTint,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('mortgage-summary-card'),
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(VeloraSpacing.lg),
          child: child,
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: VeloraColors.plum,
        borderRadius: BorderRadius.circular(VeloraRadii.control),
      ),
      child: child,
    );
  }
}
