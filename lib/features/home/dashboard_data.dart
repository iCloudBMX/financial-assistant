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
  final Currency primaryCurrency;

  /// Safe-limit view model, resolved by `dashboardProvider` so the Home
  /// cards consume immutable values instead of watching providers directly.
  /// Nullable on the pure [buildDashboard] path (which does not compute the
  /// safe-limit engine); always populated when assembled by the provider.
  final SafeLimit? safeLimit;

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
    required this.primaryCurrency,
    this.safeLimit,
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
  List<String> overspendCategories = const [],
  PrimaryGoalSummary? primaryGoal,
  MortgageSummaryView? mortgageSummary,
}) {
  final period = FinancialPeriod.containing(now, periodStartDay);
  return DashboardData(
    totals: totalsByCurrency(accounts, entries),
    monthIncome: periodIncome(entries, period, primaryCurrency),
    monthExpense: periodExpense(entries, period, primaryCurrency),
    todaySpent: spentOn(now, entries, primaryCurrency),
    primaryCurrency: primaryCurrency,
    safeLimit: safeLimit,
    overspendCategories: overspendCategories,
    primaryGoal: primaryGoal,
    mortgageSummary: mortgageSummary,
  );
}
