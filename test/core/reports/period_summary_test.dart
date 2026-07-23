import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/reports/period_summary.dart';
import 'package:financial_assistant/core/time/financial_period.dart';
import 'package:flutter_test/flutter_test.dart';

const uzs = CurrencyRegistry.uzs;
Money m(int v) => Money(v, uzs);

Account acc(int id, AccountRole role, int opening) => Account(
      id: id, name: 'a$id', type: AccountType.cash,
      openingBalance: m(opening), icon: 'wallet', archived: false, role: role);

LedgerEntry expense(int accId, int mag, DateTime at, {int? cat}) => LedgerEntry(
      id: 0, accountId: accId, type: LedgerEntryType.expense,
      amount: Money(-mag, uzs), allocated: Money.zero(uzs),
      occurredAt: at, categoryId: cat);

LedgerEntry income(int accId, int amt, DateTime at) => LedgerEntry(
      id: 0, accountId: accId, type: LedgerEntryType.income,
      amount: m(amt), allocated: Money.zero(uzs), occurredAt: at);

void main() {
  final period = FinancialPeriod.containing(DateTime(2026, 7, 15), 1); // Jul 1..Aug 1
  final inside = DateTime(2026, 7, 10);
  final outside = DateTime(2026, 6, 20);

  test('spendingLeftover sums only spending-role accounts in currency', () {
    final accounts = [acc(1, AccountRole.spending, 500000), acc(2, AccountRole.reserve, 900000)];
    // spending account 1: opening 500000 minus a 200000 expense = 300000
    final entries = [expense(1, 200000, inside)];
    expect(spendingLeftover(accounts, entries, uzs), m(300000));
  });

  test('buildMonthlySummary splits mandatory vs variable and scopes to period', () {
    final accounts = [acc(1, AccountRole.spending, 1000000)];
    final entries = [
      income(1, 2000000, inside),
      expense(1, 300000, inside, cat: 10), // mandatory
      expense(1, 150000, inside, cat: 20), // variable
      expense(1, 99999, inside),           // no category -> variable
      expense(1, 777, outside, cat: 10),   // out of period -> ignored
    ];
    final s = buildMonthlySummary(
      accounts: accounts, entries: entries,
      mandatoryCategoryIds: {10}, period: period, currency: uzs);
    expect(s.income, m(2000000));
    expect(s.expense, m(549999));
    expect(s.mandatoryExpense, m(300000));
    expect(s.variableExpense, m(249999));
  });
}
