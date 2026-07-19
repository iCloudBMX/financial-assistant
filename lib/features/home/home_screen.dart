import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_async_state.dart';
import '../accounts/transfer_sheet.dart';
import '../allocation/income_allocation_prompt.dart';
import '../expense_entry/expense_entry_sheet.dart';
import '../goals/goal_contribute_sheet.dart';
import '../goals/goal_detail_screen.dart';
import '../goals/goal_edit_sheet.dart';
import '../income_entry/income_entry_sheet.dart';
import '../mortgage/mortgage_dashboard_screen.dart';
import '../mortgage/mortgage_payment_sheet.dart';
import '../mortgage/mortgage_summary_card.dart';
import '../recurring/recurring_prompt.dart';
import '../shell/routes.dart';
import 'dashboard_data.dart';
import 'home_summary_cards.dart';
import 'safe_limit_cards.dart';

/// Whether Home's total-balance amount is masked. Session-scoped (survives
/// navigation within the running app, resets on cold start) — Home has no
/// other durable per-device UI preference storage yet.
final balanceVisibilityProvider = StateProvider<bool>((ref) => false);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bosh sahifa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => context.pushNamed(RouteNames.accounts),
          ),
        ],
      ),
      body: async.when(
        loading: () => const _HomeSkeleton(),
        error: (e, _) => VeloraErrorState(
          message: 'Bosh sahifani yuklab bo\'lmadi',
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (d) => _HomeBody(data: d),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(VeloraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VeloraSkeleton(width: double.infinity, height: 96),
          SizedBox(height: VeloraSpacing.md),
          VeloraSkeleton(width: double.infinity, height: 140),
          SizedBox(height: VeloraSpacing.md),
          VeloraSkeleton(width: double.infinity, height: 96),
        ],
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = data;
    final hidden = ref.watch(balanceVisibilityProvider);
    final hasUnallocated =
        d.unallocatedEntryId != null &&
        (d.unallocatedEntryAmount?.minorUnits ?? 0) > 0;

    // A ListView (not a SingleChildScrollView+Column) so Home participates
    // in PageStorage scroll-offset retention like the other shell tabs when
    // switching branches — see routes_test.dart's scroll-retention contract.
    return ListView(
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      children: [
        const RecurringPromptBanner(),
        TotalBalanceCard(
          key: const Key('balance-card'),
          totals: d.totals,
          hidden: hidden,
          onToggleHidden: () =>
              ref.read(balanceVisibilityProvider.notifier).update((v) => !v),
        ),
        const SizedBox(height: VeloraSpacing.md),
        const SafeLimitCard(),
        const SizedBox(height: VeloraSpacing.md),
        QuickActionsRow(
          key: const Key('quick-actions-row'),
          onExpense: () => showExpenseEntrySheet(context, ref),
          onIncome: () => showIncomeEntrySheet(context, ref),
          onAllocate: hasUnallocated
              ? () => showAllocationChoice(
                  context,
                  ref,
                  incomeId: d.unallocatedEntryId!,
                  amount: d.unallocatedEntryAmount!,
                )
              : null,
          onGoalContribution: () => d.primaryGoal == null
              ? showGoalEditSheet(context, ref)
              : showGoalContributeSheet(
                  context,
                  ref,
                  goalId: d.primaryGoal!.id,
                ),
          onMortgagePayment: () => d.mortgageSummary == null
              ? Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MortgageDashboardScreen(),
                  ),
                )
              : showMortgagePaymentSheet(context, ref, d.mortgageSummary!.id),
        ),
        if (hasUnallocated) ...[
          const SizedBox(height: VeloraSpacing.md),
          UnallocatedAlertCard(
            key: const Key('unallocated-alert'),
            amount: d.unallocatedEntryAmount!,
            onAllocate: () => showAllocationChoice(
              context,
              ref,
              incomeId: d.unallocatedEntryId!,
              amount: d.unallocatedEntryAmount!,
            ),
          ),
        ],
        const SizedBox(height: VeloraSpacing.md),
        const WeeklySafeLimitCard(),
        const SizedBox(height: VeloraSpacing.md),
        PrimaryGoalSummaryCard(
          key: const Key('goal-summary-card'),
          goal: d.primaryGoal,
          onTap: d.primaryGoal == null
              ? () {}
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GoalDetailScreen(goalId: d.primaryGoal!.id),
                  ),
                ),
          onCreate: () => showGoalEditSheet(context, ref),
        ),
        const SizedBox(height: VeloraSpacing.md),
        const MortgageSummaryCard(),
        const SizedBox(height: VeloraSpacing.xl),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showTransferSheet(context, ref),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('O\'tkazma'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
