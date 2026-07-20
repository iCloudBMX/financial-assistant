import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../ui/components/velora_card.dart';
import '../../ui/components/velora_status.dart';
import 'dashboard_data.dart';

/// One horizontal row of the five Home quick actions (§6.2 step 3): expense,
/// income, allocation, goal contribution, mortgage payment. The first
/// (expense) is the single coral primary action from the mockup; the rest use
/// the soft plum tint. Callbacks are nullable so an action can be
/// omitted/disabled when the destination has no meaningful target yet (e.g.
/// nothing left to allocate).
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
      _QuickAction(
          'expense', Icons.remove, 'Chiqim', onExpense, primary: true),
      _QuickAction('income', Icons.add, 'Kirim', onIncome),
      _QuickAction('allocate', Icons.pie_chart_outline, 'Taqsimlash', onAllocate),
      _QuickAction('goal-contribution', Icons.flag_outlined, 'Maqsadga',
          onGoalContribution),
      _QuickAction('mortgage-payment', Icons.account_balance_outlined, "To'lov",
          onMortgagePayment),
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
  final bool primary;
  const _QuickAction(this.id, this.icon, this.label, this.onTap,
      {this.primary = false});
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = action.onTap != null;
    final Color fill;
    final Color fg;
    if (!enabled) {
      fill = VeloraColors.plumTint.withValues(alpha: 0.5);
      fg = theme.colorScheme.outline;
    } else if (action.primary) {
      fill = VeloraColors.coral;
      fg = Colors.white;
    } else {
      fill = VeloraColors.plumTint;
      fg = VeloraColors.plum;
    }
    return SizedBox(
      key: Key('quick-action-${action.id}'),
      width: action.primary ? 96 : 84,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(VeloraRadii.control),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: VeloraSpacing.md, horizontal: VeloraSpacing.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(action.icon, color: fg),
                  const SizedBox(height: VeloraSpacing.xs),
                  Text(
                    action.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
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

/// The Home primary-goal summary (§6.2 step 6, first half). The mockup renders
/// it as a warm apricot-tinted card with a rounded icon tile. Shows a
/// reachable creation CTA when there is no active goal yet, matching the
/// pattern used by `MortgageSummaryCard`'s empty state.
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
      return _GoalShell(
        onTap: onCreate,
        child: Row(
          children: [
            const _GoalIconTile(child: Icon(Icons.flag_outlined,
                color: VeloraColors.plum, size: 20)),
            const SizedBox(width: VeloraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Asosiy maqsad', style: theme.textTheme.titleMedium),
                  const SizedBox(height: VeloraSpacing.xs),
                  Text("Birinchi maqsadingizni qo'shing",
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
    final progress = (g.percentBp / 10000).clamp(0.0, 1.0);
    return _GoalShell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _GoalIconTile(
                child: Icon(Icons.flag_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: VeloraSpacing.md),
              Expanded(
                child: Text(g.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Text('${(g.percentBp / 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: VeloraColors.plum)),
            ],
          ),
          const SizedBox(height: VeloraSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation(VeloraColors.apricot),
            ),
          ),
          const SizedBox(height: VeloraSpacing.sm),
          Text('${g.saved.format()} / ${g.target.format()}',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: VeloraColors.muted)),
          Text("Qoldi: ${g.remaining.format()}",
              style:
                  theme.textTheme.bodySmall?.copyWith(color: VeloraColors.muted)),
        ],
      ),
    );
  }
}

class _GoalShell extends StatelessWidget {
  const _GoalShell({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(VeloraRadii.card);
    return Material(
      color: VeloraColors.apricotTint,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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

class _GoalIconTile extends StatelessWidget {
  const _GoalIconTile({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: VeloraColors.apricot,
        borderRadius: BorderRadius.circular(VeloraRadii.control),
      ),
      child: child,
    );
  }
}
