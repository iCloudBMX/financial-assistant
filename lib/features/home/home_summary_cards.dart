import 'package:flutter/material.dart';

import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../ui/components/velora_card.dart';
import '../../ui/components/velora_status.dart';
import 'dashboard_data.dart';

/// Total available balance (§6.2 step 1), with a privacy toggle so sensitive
/// amounts can be masked without leaving Home (§5.4).
class TotalBalanceCard extends StatelessWidget {
  const TotalBalanceCard({
    super.key,
    required this.totals,
    required this.hidden,
    required this.onToggleHidden,
  });

  final Map<Currency, Money> totals;
  final bool hidden;
  final VoidCallback onToggleHidden;

  static const _mask = '••••••';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = totals.entries.map((e) => e.value.format()).toList();
    final display = lines.isEmpty ? '—' : lines.join('\n');
    return VeloraCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Jami mavjud balans', style: theme.textTheme.bodyMedium),
                const SizedBox(height: VeloraSpacing.xs),
                Text(
                  key: const Key('balance-amount'),
                  hidden ? _mask : display,
                  style: theme.textTheme.headlineSmall,
                  semanticsLabel: hidden
                      ? 'Balans yashirilgan'
                      : lines.join(', '),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: IconButton(
              key: const Key('balance-privacy-toggle'),
              icon: Icon(hidden ? Icons.visibility_off : Icons.visibility),
              tooltip: hidden ? "Balansni ko'rsatish" : 'Balansni yashirish',
              onPressed: onToggleHidden,
            ),
          ),
        ],
      ),
    );
  }
}

/// One horizontal row of the five Home quick actions (§6.2 step 3): expense,
/// income, allocation, goal contribution, mortgage payment. Callbacks are
/// nullable so an action can be omitted/disabled when the destination has no
/// meaningful target yet (e.g. nothing left to allocate).
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({
    super.key,
    required this.onExpense,
    required this.onIncome,
    required this.onAllocate,
    required this.onGoalContribution,
    required this.onMortgagePayment,
  });

  final VoidCallback onExpense;
  final VoidCallback onIncome;
  final VoidCallback? onAllocate;
  final VoidCallback onGoalContribution;
  final VoidCallback onMortgagePayment;

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction('expense', Icons.remove_circle_outline, 'Chiqim', onExpense),
      _QuickAction('income', Icons.add_circle_outline, 'Kirim', onIncome),
      _QuickAction(
          'allocate', Icons.pie_chart_outline, "Taqsimlash", onAllocate),
      _QuickAction('goal-contribution', Icons.flag_outlined, 'Maqsadga',
          onGoalContribution),
      _QuickAction('mortgage-payment', Icons.account_balance_outlined,
          "To'lov", onMortgagePayment),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final a in actions) ...[
            _QuickActionButton(action: a),
            const SizedBox(width: VeloraSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _QuickAction {
  final String id;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _QuickAction(this.id, this.icon, this.label, this.onTap);
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = action.onTap != null;
    return SizedBox(
      key: Key('quick-action-${action.id}'),
      width: 84,
      child: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VeloraRadii.control),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: VeloraSpacing.sm, horizontal: VeloraSpacing.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    action.icon,
                    color: enabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  const SizedBox(height: VeloraSpacing.xs),
                  Text(
                    action.label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: enabled ? null : theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The unallocated-income alert (§6.2 step 4). Shown by the caller only when
/// the amount is non-zero — a constructive nudge, not an error, so it uses
/// the "near" status tone rather than red (§ global constraints).
class UnallocatedAlertCard extends StatelessWidget {
  const UnallocatedAlertCard({
    super.key,
    required this.amount,
    required this.onAllocate,
  });

  final Money amount;
  final VoidCallback onAllocate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A Column — not a Row — around the badge: `VeloraStatusBadge` sizes to
    // its label's natural (unwrapped) width when a Row hands it unbounded
    // space, which overflowed at 200% text scale. A Column bounds its width
    // to the card, so the badge's own internal `Flexible` can wrap/ellipsize
    // correctly.
    return VeloraCard(
      onTap: onAllocate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VeloraStatusBadge(
            color: VeloraColors.apricot,
            icon: Icons.info_outline,
            label: 'Taqsimlanmagan',
          ),
          const SizedBox(height: VeloraSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  "${amount.format()} taqsimlanmagan",
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ],
      ),
    );
  }
}

/// The Home primary-goal summary (§6.2 step 6, first half). Shows a reachable
/// creation CTA when there is no active goal yet, matching the pattern used
/// by `MortgageSummaryCard`'s empty state.
class PrimaryGoalSummaryCard extends StatelessWidget {
  const PrimaryGoalSummaryCard({
    super.key,
    required this.goal,
    required this.onTap,
    required this.onCreate,
  });

  final PrimaryGoalSummary? goal;
  final VoidCallback onTap;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = goal;
    if (g == null) {
      return VeloraCard(
        onTap: onCreate,
        child: Row(
          children: [
            Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: VeloraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Asosiy maqsad', style: theme.textTheme.titleMedium),
                  const SizedBox(height: VeloraSpacing.xs),
                  const Text("Birinchi maqsadingizni qo'shing"),
                ],
              ),
            ),
            const Icon(Icons.add),
          ],
        ),
      );
    }
    final progress = (g.percentBp / 10000).clamp(0.0, 1.0);
    return VeloraCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: VeloraSpacing.sm),
              Expanded(
                child: Text(g.name, style: theme.textTheme.titleMedium),
              ),
              Text('${(g.percentBp / 100).toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: VeloraSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(VeloraRadii.control),
            child: LinearProgressIndicator(value: progress),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          Text('${g.saved.format()} / ${g.target.format()}',
              style: theme.textTheme.bodySmall),
          Text("Qoldi: ${g.remaining.format()}",
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
