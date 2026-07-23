import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/money/money.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../providers/month_close_providers.dart';
import '../../ui/components/velora_async_state.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_card.dart';
import '../goals/goal_contribute_sheet.dart';
import '../mortgage/mortgage_extra_payment_sheet.dart';
import '../shell/routes.dart';
import 'month_close_data.dart';

/// §16.1 soft-ceremony month-close summary: what happened last period, plus
/// a single "Oyni yopish" action that marks it closed. No forced flow — the
/// user can dismiss (back button) and be offered the same period again next
/// visit to Reports.
class MonthCloseScreen extends ConsumerWidget {
  const MonthCloseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(monthCloseProvider);
    return Scaffold(
      backgroundColor: VeloraColors.blush,
      appBar: AppBar(
        title: const Text('Oyni yopish'),
        backgroundColor: VeloraColors.blush,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: VeloraColors.inkberry,
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => VeloraErrorState(
          message: 'Xatolik yuz berdi',
          onRetry: () => ref.invalidate(monthCloseProvider),
        ),
        data: (value) => value == null
            ? const VeloraEmptyState(
                icon: Icons.check_circle_outline,
                title: 'Yopiladigan davr yo\'q',
              )
            : _MonthCloseBody(data: value),
      ),
    );
  }
}

class _MonthCloseBody extends ConsumerWidget {
  const _MonthCloseBody({required this.data});

  final MonthCloseData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final leftover = data.summary.leftover;
    final overspent = leftover.isNegative;
    final saveOrOverLabel = overspent ? 'Oshib ketdi' : 'Tejaldi';
    final saveOrOverValue = overspent ? leftover.negate() : leftover;

    return ListView(
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      children: [
        VeloraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(periodLabel(data.period), style: theme.textTheme.titleLarge),
              const SizedBox(height: VeloraSpacing.md),
              _row(context, 'Daromad', data.summary.income),
              _row(context, 'Xarajat', data.summary.expense),
              _row(context, saveOrOverLabel, saveOrOverValue),
              _row(context, "Maqsadga ajratilgan", data.goalAllocated),
              _row(context, 'Taqsimlanmagan', leftover),
            ],
          ),
        ),
        const SizedBox(height: VeloraSpacing.lg),
        _LeftoverDistribution(leftover: leftover),
        const SizedBox(height: VeloraSpacing.lg),
        VeloraPrimaryButton(
          label: 'Oyni yopish',
          onPressed: () async {
            await ref.read(closePeriodProvider)(data.period.start);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, Money value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: VeloraSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: VeloraSpacing.sm),
          Text(
            value.format(),
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

/// §16.2 destination chooser: reuses the existing goal-contribute,
/// mortgage-extra-payment, and allocation-plan flows rather than building new
/// transfer UI. Each destination prefills with the current leftover; the
/// screen above rebuilds from `monthCloseProvider` once a sheet returns, so
/// the leftover shown here always reflects live balances.
class _LeftoverDistribution extends ConsumerWidget {
  const _LeftoverDistribution({required this.leftover});

  final Money leftover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final amount =
        leftover.isNegative ? Money.zero(leftover.currency) : leftover;
    final hasLeftover = amount.minorUnits > 0;

    return VeloraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Qoldiqni taqsimlash', style: theme.textTheme.titleMedium),
          const SizedBox(height: VeloraSpacing.xs),
          Text(
            amount.format(),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: VeloraColors.muted),
          ),
          const SizedBox(height: VeloraSpacing.md),
          Row(
            children: [
              Expanded(
                child: _DestinationTile(
                  icon: Icons.flag_outlined,
                  label: 'Maqsadga',
                  onTap: hasLeftover
                      ? () => _pickGoal(context, ref, amount)
                      : null,
                ),
              ),
              const SizedBox(width: VeloraSpacing.sm),
              Expanded(
                child: _DestinationTile(
                  icon: Icons.home_outlined,
                  label: 'Ipotekaga',
                  onTap: hasLeftover
                      ? () => _pickMortgage(context, ref, amount)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: VeloraSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _DestinationTile(
                  icon: Icons.savings_outlined,
                  label: 'Zaxiraga',
                  onTap: () {
                    Navigator.of(context).pop();
                    context.goNamed(RouteNames.plan);
                  },
                ),
              ),
              const SizedBox(width: VeloraSpacing.sm),
              Expanded(
                child: _DestinationTile(
                  icon: Icons.arrow_forward_outlined,
                  label: 'Keyingi oyga',
                  onTap: () {}, // no-op: leftover stays in spending accounts
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickGoal(
      BuildContext context, WidgetRef ref, Money amount) async {
    final goals = await ref.read(goalsProvider.future);
    if (goals.isEmpty || !context.mounted) return;
    final goalId = await showDialog<int>(
      context: context,
      builder: (dctx) => SimpleDialog(
        title: const Text('Qaysi maqsadga?'),
        children: goals
            .map((g) => SimpleDialogOption(
                  onPressed: () => Navigator.of(dctx).pop(g.goal.id),
                  child: Text(g.goal.name),
                ))
            .toList(),
      ),
    );
    if (goalId != null && context.mounted) {
      // ignore: use_build_context_synchronously
      await showGoalContributeSheet(context, ref,
          goalId: goalId, initialAmount: amount);
    }
  }

  Future<void> _pickMortgage(
      BuildContext context, WidgetRef ref, Money amount) async {
    final mortgages = await ref.read(mortgagesProvider.future);
    if (mortgages.isEmpty || !context.mounted) return;
    final mortgageId = await showDialog<int>(
      context: context,
      builder: (dctx) => SimpleDialog(
        title: const Text('Qaysi ipotekaga?'),
        children: mortgages
            .map((m) => SimpleDialogOption(
                  onPressed: () => Navigator.of(dctx).pop(m.mortgage.id),
                  child: Text(m.mortgage.name),
                ))
            .toList(),
      ),
    );
    if (mortgageId != null && context.mounted) {
      // ignore: use_build_context_synchronously
      await showMortgageExtraPaymentSheet(context, ref, mortgageId,
          initialAmount: amount);
    }
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
