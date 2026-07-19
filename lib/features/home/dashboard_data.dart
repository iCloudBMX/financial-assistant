import '../../core/ledger/account.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/ledger/summary_engine.dart';
import '../../core/limit/safe_limit_engine.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/time/financial_period.dart';

/// The §12.4 goal-card figures needed for the Home primary-goal summary.
/// Built by the provider layer from [GoalWithProgress]; kept independent of
/// Riverpod so this file stays a pure, widget-free data module.
class PrimaryGoalSummary {
  final int id;
  final String name;
  final String icon;
  final Money saved;
  final Money target;
  final int percentBp; // 0..10000
  final Money remaining;
  const PrimaryGoalSummary({
    required this.id,
    required this.name,
    required this.icon,
    required this.saved,
    required this.target,
    required this.percentBp,
    required this.remaining,
  });
}

/// The Home mortgage-summary figures. Built by the provider layer from
/// `MortgageWithProjection`; kept independent of Riverpod for the same
/// reason as [PrimaryGoalSummary].
class MortgageSummaryView {
  final int id;
  final String name;
  final Money currentPrincipal;
  final Money nextPaymentAmount;
  final DateTime nextPaymentDate;
  final int completionBp; // 0..10000
  const MortgageSummaryView({
    required this.id,
    required this.name,
    required this.currentPrincipal,
    required this.nextPaymentAmount,
    required this.nextPaymentDate,
    required this.completionBp,
  });
}

class DashboardData {
  final Map<Currency, Money> totals; // balance-by-currency
  final Money monthIncome;
  final Money monthExpense;
  final Money todaySpent;
  final Money undistributedFunds; // unallocated income, all entries, summed
  final Currency primaryCurrency;

  /// The most recently occurred income entry that still has an unallocated
  /// remainder, if any. Drives the unallocated-income alert CTA and the
  /// "allocation" quick action without HomeScreen touching the ledger
  /// repository directly.
  final int? unallocatedEntryId;
  final Money? unallocatedEntryAmount;

  /// Safe-limit view models, resolved by `dashboardProvider` so the Home
  /// cards consume immutable values instead of watching providers directly.
  /// Nullable on the pure [buildDashboard] path (which does not compute the
  /// safe-limit engine); always populated when assembled by the provider.
  final SafeLimit? safeLimit;
  final WeeklySafeLimit? weeklyLimit;

  /// Names of variable categories over their monthly limit — the offenders
  /// line under the safe-limit hero when it is over.
  final List<String> overspendCategories;

  final PrimaryGoalSummary? primaryGoal;
  final MortgageSummaryView? mortgageSummary;

  const DashboardData({
    required this.totals,
    required this.monthIncome,
    required this.monthExpense,
    required this.todaySpent,
    required this.undistributedFunds,
    required this.primaryCurrency,
    this.unallocatedEntryId,
    this.unallocatedEntryAmount,
    this.safeLimit,
    this.weeklyLimit,
    this.overspendCategories = const [],
    this.primaryGoal,
    this.mortgageSummary,
  });
}

DashboardData buildDashboard({
  required Iterable<Account> accounts,
  required Iterable<LedgerEntry> entries,
  required Currency primaryCurrency,
  required int periodStartDay,
  required DateTime now,
  SafeLimit? safeLimit,
  WeeklySafeLimit? weeklyLimit,
  List<String> overspendCategories = const [],
  PrimaryGoalSummary? primaryGoal,
  MortgageSummaryView? mortgageSummary,
}) {
  final period = FinancialPeriod.containing(now, periodStartDay);
  final latest = _latestUnallocatedIncome(entries, primaryCurrency);
  return DashboardData(
    totals: totalsByCurrency(accounts, entries),
    monthIncome: periodIncome(entries, period, primaryCurrency),
    monthExpense: periodExpense(entries, period, primaryCurrency),
    todaySpent: spentOn(now, entries, primaryCurrency),
    undistributedFunds: undistributed(entries, primaryCurrency),
    primaryCurrency: primaryCurrency,
    safeLimit: safeLimit,
    weeklyLimit: weeklyLimit,
    overspendCategories: overspendCategories,
    unallocatedEntryId: latest?.id,
    // The remaining unallocated amount (amount − allocated), NOT the gross
    // entry amount: this flows into showAllocationChoice →
    // AllocationRepository.allocateIncome, which rebuilds the entry's
    // allocation against this base. Passing the gross amount for an already
    // partially-allocated entry would discard the prior partial allocation.
    unallocatedEntryAmount: latest == null
        ? null
        : Money(latest.amount.minorUnits - latest.allocated.minorUnits,
            latest.amount.currency),
    primaryGoal: primaryGoal,
    mortgageSummary: mortgageSummary,
  );
}

/// The most recent income entry whose amount exceeds what has been
/// allocated, i.e. `amount − allocated > 0`. Ties broken by insertion order
/// (later entries in the iterable win) since `occurredAt` alone is not a
/// stable tiebreaker.
LedgerEntry? _latestUnallocatedIncome(
    Iterable<LedgerEntry> entries, Currency currency) {
  LedgerEntry? best;
  for (final e in entries) {
    if (e.type != LedgerEntryType.income) continue;
    if (e.amount.currency != currency) continue;
    if (e.amount.minorUnits - e.allocated.minorUnits <= 0) continue;
    if (best == null || !e.occurredAt.isBefore(best.occurredAt)) best = e;
  }
  return best;
}
