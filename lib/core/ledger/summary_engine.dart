import '../money/currency.dart';
import '../money/money.dart';
import '../time/financial_period.dart';
import 'account.dart';
import 'balance_engine.dart';
import 'ledger_entry.dart';

Map<Currency, Money> totalsByCurrency(
    Iterable<Account> accounts, Iterable<LedgerEntry> entries) {
  final totals = <Currency, Money>{};
  for (final a in accounts) {
    final bal = accountBalance(a, entries);
    final running = totals[a.currency];
    totals[a.currency] = running == null ? bal : running.add(bal);
  }
  return totals;
}

Money periodIncome(
    Iterable<LedgerEntry> entries, FinancialPeriod period, Currency currency) {
  var sum = 0;
  for (final e in entries) {
    if (e.type != LedgerEntryType.income) continue;
    if (e.amount.currency != currency) continue;
    if (!period.contains(e.occurredAt)) continue;
    sum += e.amount.minorUnits;
  }
  return Money(sum, currency);
}

Money periodExpense(
    Iterable<LedgerEntry> entries, FinancialPeriod period, Currency currency) {
  var sum = 0;
  for (final e in entries) {
    if (e.type != LedgerEntryType.expense) continue;
    if (e.amount.currency != currency) continue;
    if (!period.contains(e.occurredAt)) continue;
    sum += -e.amount.minorUnits; // magnitude
  }
  return Money(sum, currency);
}

Money spentOn(
    DateTime day, Iterable<LedgerEntry> entries, Currency currency) {
  var sum = 0;
  for (final e in entries) {
    if (e.type != LedgerEntryType.expense) continue;
    if (e.amount.currency != currency) continue;
    final d = e.occurredAt;
    if (d.year == day.year && d.month == day.month && d.day == day.day) {
      sum += -e.amount.minorUnits;
    }
  }
  return Money(sum, currency);
}

Map<int, Money> categorySpent(
    Iterable<LedgerEntry> entries, FinancialPeriod period, Currency currency) {
  final out = <int, Money>{};
  for (final e in entries) {
    if (e.type != LedgerEntryType.expense) continue;
    if (e.amount.currency != currency) continue;
    if (e.categoryId == null) continue;
    if (!period.contains(e.occurredAt)) continue;
    final running = out[e.categoryId!];
    final add = Money(-e.amount.minorUnits, currency);
    out[e.categoryId!] = running == null ? add : running.add(add);
  }
  return out;
}

Money undistributed(Iterable<LedgerEntry> entries, Currency currency) {
  var sum = 0;
  for (final e in entries) {
    if (e.type != LedgerEntryType.income) continue;
    if (e.amount.currency != currency) continue;
    sum += e.amount.minorUnits - e.allocated.minorUnits;
  }
  return Money(sum, currency);
}
