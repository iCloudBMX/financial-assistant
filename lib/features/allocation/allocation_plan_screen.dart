import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/allocation/allocation_plan.dart';
import '../../core/allocation/allocation_plan_engine.dart';
import '../../core/money/money.dart';
import '../../core/result/failure_messages.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/account_card_picker.dart';
import '../../ui/components/app_snackbar.dart';
import '../../ui/components/velora_button.dart';
import '../../ui/components/velora_card.dart';
import '../accounts/account_labels.dart';
import '../accounts/accounts_controller.dart';
import 'allocation_plan_controller.dart';
import 'allocation_rule_sheet.dart';
import 'apply_plan_sheet.dart';

/// The manual allocation plan: designate a source card, list fixed-amount
/// rules to other cards, and apply them all (after a confirm) as internal
/// transfers. Reached from the Budget page header.
class AllocationPlanScreen extends ConsumerWidget {
  const AllocationPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(allocationPlanProvider);
    final accountsAsync = ref.watch(accountsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Taqsimlash rejasi')),
      // Every source-card swipe persists the selection, which bumps the global
      // ledger revision and reloads both providers. skipLoadingOnReload keeps
      // the last data on screen during those reloads so the picker's PageView
      // is never torn down and rebuilt mid-swipe (a full-screen spinner flash).
      body: planAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Xatolik yuz berdi')),
        data: (plan) => accountsAsync.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('Xatolik yuz berdi')),
          data: (accounts) =>
              _PlanBody(plan: plan, accounts: accounts),
        ),
      ),
    );
  }
}

class _PlanBody extends ConsumerStatefulWidget {
  const _PlanBody({required this.plan, required this.accounts});
  final AllocationPlan plan;
  final List<AccountWithBalance> accounts;

  @override
  ConsumerState<_PlanBody> createState() => _PlanBodyState();
}

class _PlanBodyState extends ConsumerState<_PlanBody> {
  bool _sourceDefaultScheduled = false;

  // Rows the user has swiped away but whose async delete has not yet landed in
  // the reloaded plan. Hidden from the build immediately so the dismissed
  // Dismissible leaves the tree this frame (otherwise Flutter asserts that a
  // dismissed widget is still present). Reconciled in didUpdateWidget once the
  // shorter (or restored) list arrives.
  final Set<int> _pendingDelete = {};

  @override
  void didUpdateWidget(covariant _PlanBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan.rules.length != widget.plan.rules.length) {
      _pendingDelete.clear();
    }
  }

  Money? _sourceBalance() {
    for (final a in widget.accounts) {
      if (a.account.id == widget.plan.sourceAccountId) return a.balance;
    }
    return null;
  }

  // The first card the source picker will actually show (same selectability as
  // the picker: non-archived, same-currency balance).
  int? _firstSelectableSourceId() {
    for (final a in widget.accounts) {
      final acc = a.account;
      if (!acc.archived && a.balance.currency == acc.currency) return acc.id;
    }
    return null;
  }

  Future<void> _apply(BuildContext context) async {
    final sourceId = widget.plan.sourceAccountId;
    final balance = _sourceBalance();
    if (sourceId == null || balance == null) return;
    final result =
        computePlanTransfers(sourceBalance: balance, rules: widget.plan.rules);
    final destNames = {
      for (final a in widget.accounts) a.account.id: a.account.name,
    };
    final sourceName = destNames[sourceId] ?? 'Manba';
    final ok = await showApplyPlanSheet(context,
        result: result, destNames: destNames, sourceName: sourceName);
    if (ok != true || !context.mounted) return;
    final res = await ref
        .read(allocationPlanControllerProvider)
        .apply(sourceId, result.transfers);
    if (!context.mounted) return;
    res.when(
      ok: (_) => ScaffoldMessenger.of(context).showAutoDismissSnackBar(
        SnackBar(content: Text('${result.totalMoved.format()} ko\'chirildi')),
      ),
      err: (f) => ScaffoldMessenger.of(context).showAutoDismissSnackBar(
        SnackBar(content: Text(userMessageFor(f))),
      ),
    );
  }

  Future<void> _addRule(BuildContext context) async {
    final sourceId = widget.plan.sourceAccountId;
    if (sourceId == null) return;
    final picked =
        await showAllocationRuleSheet(context, ref, sourceAccountId: sourceId);
    if (picked == null) return;
    final next = [
      ...widget.plan.rules,
      AllocationRule(
          destinationAccountId: picked.destinationAccountId,
          amount: picked.amount,
          sortOrder: widget.plan.rules.length),
    ];
    await ref.read(allocationPlanControllerProvider).saveRules(next);
  }

  Future<void> _editRule(BuildContext context, int index) async {
    final sourceId = widget.plan.sourceAccountId;
    if (sourceId == null) return;
    final r = widget.plan.rules[index];
    final picked = await showAllocationRuleSheet(context, ref,
        sourceAccountId: sourceId,
        initial: (destinationAccountId: r.destinationAccountId, amount: r.amount));
    if (picked == null) return;
    final next = [...widget.plan.rules];
    next[index] = r.copyWith(
        destinationAccountId: picked.destinationAccountId, amount: picked.amount);
    await ref.read(allocationPlanControllerProvider).saveRules(next);
  }

  // Swipe-to-delete. The row is already hidden via _pendingDelete; persist the
  // shorter list, then offer an Undo that re-saves the exact prior list.
  Future<void> _deleteRuleWithUndo(BuildContext context, int index) async {
    final previous = [...widget.plan.rules];
    final next = [...previous]..removeAt(index);
    // Hide the row this frame so the dismissed Dismissible leaves the tree
    // before its next build (the async save + reload lands a frame later).
    setState(() => _pendingDelete.add(index));
    await ref.read(allocationPlanControllerProvider).saveRules(next);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showAutoDismissSnackBar(
      SnackBar(
        content: const Text('Qator o\'chirildi'),
        action: SnackBarAction(
          label: 'Bekor qilish',
          onPressed: () =>
              ref.read(allocationPlanControllerProvider).saveRules(previous),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = widget.plan;
    final accounts = widget.accounts;
    final sourceId = plan.sourceAccountId;

    // Default the source to the first card the picker shows so the user need
    // not tap it. Persist once (guarded against re-entry during the async
    // revision bump). setSource only records the allocation source; it does
    // not feed the daily-limit calculation.
    if (sourceId == null && !_sourceDefaultScheduled) {
      final firstId = _firstSelectableSourceId();
      if (firstId != null) {
        _sourceDefaultScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(allocationPlanControllerProvider).setSource(firstId);
          }
        });
      }
    }

    final balances = {for (final a in accounts) a.account.id: a.balance};
    final nameOf = {for (final a in accounts) a.account.id: a.account.name};
    final accountById = {for (final a in accounts) a.account.id: a.account};
    final canApply = sourceId != null && plan.rules.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(VeloraSpacing.lg),
            children: [
              Text('MANBA KARTA',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: VeloraColors.muted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
              const SizedBox(height: VeloraSpacing.sm),
              AccountCardPicker(
                key: const Key('plan-source-picker'),
                accounts: [for (final a in accounts) a.account],
                availableBalances: balances,
                selectedId: sourceId,
                onSelected: (id) => ref
                    .read(allocationPlanControllerProvider)
                    .setSource(id),
              ),
              const SizedBox(height: VeloraSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text('Qatorlar',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  TextButton.icon(
                    key: const Key('plan-add-rule'),
                    onPressed: sourceId == null
                        ? null
                        : () => _addRule(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Yangi qator'),
                  ),
                ],
              ),
              const SizedBox(height: VeloraSpacing.sm),
              if (sourceId == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: VeloraSpacing.md),
                  child: Text('Avval manba kartani tanlang.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: VeloraColors.muted)),
                )
              else if (plan.rules.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: VeloraSpacing.md),
                  child: Text('Hali qator yo\'q. "Yangi qator" bilan qo\'shing.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: VeloraColors.muted)),
                )
              else
                for (var i = 0; i < plan.rules.length; i++)
                  if (!_pendingDelete.contains(i))
                    Padding(
                      padding: const EdgeInsets.only(bottom: VeloraSpacing.sm),
                      // Swipe left to delete (mobile-native affordance; there is
                      // no ⊖ button). Undo is offered via a snackbar.
                      child: Dismissible(
                        key: Key('plan-rule-$i'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _deleteRuleWithUndo(context, i),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: VeloraSpacing.lg),
                          decoration: BoxDecoration(
                            color: VeloraColors.critical,
                            borderRadius:
                                BorderRadius.circular(VeloraRadii.card),
                          ),
                          child: const Icon(Icons.delete_outline,
                              color: Colors.white),
                        ),
                        child: VeloraCard(
                          onTap: () => _editRule(context, i),
                          child: Row(
                            children: [
                              if (accountById[
                                      plan.rules[i].destinationAccountId] !=
                                  null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      right: VeloraSpacing.sm),
                                  child: Icon(
                                    accountTypeIcon(
                                      accountById[plan
                                              .rules[i].destinationAccountId]!
                                          .type,
                                      icon: accountById[plan
                                              .rules[i].destinationAccountId]!
                                          .icon,
                                    ),
                                    color: VeloraColors.muted,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  nameOf[plan.rules[i].destinationAccountId] ??
                                      'O\'chirilgan karta',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              Text(plan.rules[i].amount.format(),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                      color: VeloraColors.plum,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(VeloraSpacing.lg),
            child: Theme(
              data: theme.copyWith(
                colorScheme: theme.colorScheme.copyWith(
                    primary: VeloraColors.coral, onPrimary: Colors.white),
              ),
              child: VeloraPrimaryButton(
                key: const Key('plan-apply'),
                label: 'Rejani qo\'llash',
                onPressed: canApply ? () => _apply(context) : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
