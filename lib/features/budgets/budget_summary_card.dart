import 'package:flutter/material.dart';
import '../../core/limit/safe_limit_engine.dart';
import '../../core/theme/velora_tokens.dart';

/// The Budget page's read-only daily-limit summary. It renders SP-B's already
/// resolved [SafeLimit] (per-day figure + spending pool); it does not recompute
/// anything and it exposes no editable fields — the user changes the pool by
/// setting card roles/balances on the Accounts screen.
class BudgetSummaryCard extends StatelessWidget {
  const BudgetSummaryCard({super.key, required this.limit});

  final SafeLimit limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onPlum = Colors.white;
    // "No Sarf-role card exists" is distinct from "Sarf cards summing to
    // zero" — only the former should nudge the user to go set one up.
    final empty = !limit.hasSpendingAccounts;

    return Container(
      key: const Key('budget-summary-card'),
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      decoration: BoxDecoration(
        color: VeloraColors.plum,
        borderRadius: BorderRadius.circular(VeloraRadii.card),
        boxShadow: const [
          BoxShadow(color: Color(0x335B3A6E), blurRadius: 26, offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BUGUNGI LIMIT',
            style: theme.textTheme.labelSmall?.copyWith(
              color: onPlum.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          if (empty)
            Text(
              'Sarf kartasi belgilang',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: onPlum, fontWeight: FontWeight.w700),
            )
          else ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                limit.perDay.format(),
                maxLines: 1,
                softWrap: false,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(color: onPlum, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: VeloraSpacing.sm),
            Text(
              "Sarf kartalari qoldig'i ${limit.spendable.format()} "
              '· ${limit.daysLeft} kun qoldi',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: onPlum.withValues(alpha: 0.82)),
            ),
          ],
        ],
      ),
    );
  }
}
