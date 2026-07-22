import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/velora_tokens.dart';
import '../../providers/app_providers.dart';
import '../../ui/components/velora_async_state.dart';
import '../accounts/transfer_sheet.dart';
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
import '../../core/limit/safe_limit_engine.dart';
import '../../core/money/money.dart';
import 'dashboard_data.dart';
import 'home_hero.dart';
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
      body: SafeArea(
        child: async.when(
          loading: () => const _HomeSkeleton(),
          error: (e, _) => VeloraErrorState(
            message: 'Bosh sahifani yuklab bo\'lmadi',
            onRetry: () => ref.invalidate(dashboardProvider),
          ),
          data: (d) => _HomeBody(data: d),
        ),
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
    final name = ref.watch(settingsProvider).asData?.value.name ?? '';

    final total =
        d.totals[d.primaryCurrency] ?? Money(0, d.primaryCurrency);
    // "Erkin" (free) is the month's spendable figure the safe-limit engine
    // already resolved; "Rezerv" (reserved) is the honest remainder,
    // total − free, floored at zero. Both stay null until a safe limit
    // exists so the minis show an em dash rather than an invented split.
    final free = d.safeLimit?.spendable;
    final reserved = free == null
        ? null
        : Money(
            (total.minorUnits - free.minorUnits).clamp(0, total.minorUnits),
            d.primaryCurrency,
          );

    // A ListView (not a SingleChildScrollView+Column) so Home participates
    // in PageStorage scroll-offset retention like the other shell tabs when
    // switching branches — see routes_test.dart's scroll-retention contract.
    return ListView(
      padding: const EdgeInsets.all(VeloraSpacing.lg),
      children: [
        const RecurringPromptBanner(),
        HomeHeader(
          name: name,
          title: _statusTitle(d.safeLimit),
          hidden: hidden,
          onToggleHidden: () =>
              ref.read(balanceVisibilityProvider.notifier).update((v) => !v),
          onOpenAccounts: () => context.pushNamed(RouteNames.accounts),
        ),
        const SizedBox(height: VeloraSpacing.lg),
        if (d.safeLimit != null) ...[
          SafeLimitCard(
            limit: d.safeLimit!,
            overspendCategories: d.overspendCategories,
          ),
          const SizedBox(height: VeloraSpacing.md),
        ],
        QuickActionsRow(
          key: const Key('quick-actions-row'),
          onExpense: () => showExpenseEntrySheet(context, ref),
          onIncome: () => showIncomeEntrySheet(context, ref),
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
        const SizedBox(height: VeloraSpacing.md),
        BalanceCard(
          total: total,
          free: free,
          reserved: reserved,
          hidden: hidden,
        ),
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
        MortgageSummaryCard(summary: d.mortgageSummary),
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

/// The warm status headline under the greeting, chosen from the day's safe
/// limit: reassuring when on track, constructive (never accusatory, §3.1)
/// when close to or past the limit.
String _statusTitle(SafeLimit? limit) {
  if (limit == null) return 'Pul rejangiz joyida';
  if (limit.isOver) return 'Bugun ehtiyotkor bo\'ling';
  if (limit.perDay.minorUnits > 0 &&
      limit.todayRemaining.minorUnits <= limit.perDay.minorUnits ~/ 5) {
    return 'Limitga yaqinlashdingiz';
  }
  return 'Pul rejangiz joyida';
}
