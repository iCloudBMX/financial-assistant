import '../../core/ledger/account.dart';
import '../../core/ledger/ledger_entry.dart';
import '../../core/ledger/summary_engine.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/time/financial_period.dart';

class DashboardData {
  final Map<Currency, Money> totals;
  final Money monthIncome;
  final Money monthExpense;
  final Money todaySpent;
  final Money undistributedFunds;
  final Currency primaryCurrency;
  const DashboardData({
    required this.totals,
    required this.monthIncome,
    required this.monthExpense,
    required this.todaySpent,
    required this.undistributedFunds,
    required this.primaryCurrency,
  });
}

DashboardData buildDashboard({
  required Iterable<Account> accounts,
  required Iterable<LedgerEntry> entries,
  required Currency primaryCurrency,
  required int periodStartDay,
  required DateTime now,
}) {
  final period = FinancialPeriod.containing(now, periodStartDay);
  return DashboardData(
    totals: totalsByCurrency(accounts, entries),
    monthIncome: periodIncome(entries, period, primaryCurrency),
    monthExpense: periodExpense(entries, period, primaryCurrency),
    todaySpent: spentOn(now, entries, primaryCurrency),
    undistributedFunds: undistributed(entries, primaryCurrency),
    primaryCurrency: primaryCurrency,
  );
}
