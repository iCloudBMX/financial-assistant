import '../ledger/account.dart';
import '../ledger/balance_engine.dart';
import '../ledger/ledger_entry.dart';
import '../ledger/summary_engine.dart';
import '../money/currency.dart';
import '../money/money.dart';
import '../time/financial_period.dart';

/// Σ balances of `spending`-role accounts in [currency]. The envelope-model
/// "leftover" / "undistributed": money budgeted to spend that wasn't. May be
/// negative (overspend). Only meaningful for the CURRENT period — it reflects
/// live account balances, not a historical end-of-period snapshot (soft
/// ceremony: no snapshots).
Money spendingLeftover(
    Iterable<Account> accounts, Iterable<LedgerEntry> entries, Currency currency) {
  var sum = 0;
  for (final a in accounts) {
    if (a.role != AccountRole.spending) continue;
    if (a.currency != currency) continue;
    sum += accountBalance(a, entries).minorUnits;
  }
  return Money(sum, currency);
}

class MonthlySummary {
  final Money income;
  final Money expense;
  final Money mandatoryExpense;
  final Money variableExpense;
  final Money leftover; // == undistributed; only read for the current period
  const MonthlySummary({
    required this.income,
    required this.expense,
    required this.mandatoryExpense,
    required this.variableExpense,
    required this.leftover,
  });
}

MonthlySummary buildMonthlySummary({
  required Iterable<Account> accounts,
  required Iterable<LedgerEntry> entries,
  required Set<int> mandatoryCategoryIds,
  required FinancialPeriod period,
  required Currency currency,
}) {
  var mandatory = 0;
  var variable = 0;
  for (final e in entries) {
    if (e.type != LedgerEntryType.expense) continue;
    if (e.amount.currency != currency) continue;
    if (!period.contains(e.occurredAt)) continue;
    final mag = -e.amount.minorUnits; // magnitude
    if (e.categoryId != null && mandatoryCategoryIds.contains(e.categoryId)) {
      mandatory += mag;
    } else {
      variable += mag; // uncategorised expense counts as variable
    }
  }
  return MonthlySummary(
    income: periodIncome(entries, period, currency),
    expense: periodExpense(entries, period, currency),
    mandatoryExpense: Money(mandatory, currency),
    variableExpense: Money(variable, currency),
    leftover: spendingLeftover(accounts, entries, currency),
  );
}
