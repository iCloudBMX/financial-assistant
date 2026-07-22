// test/core/ledger/summary_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/time/financial_period.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/core/ledger/summary_engine.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  const usd = CurrencyRegistry.usd;
  final period = FinancialPeriod.containing(DateTime(2026, 7, 18), 1); // Jul 1..Aug 1

  LedgerEntry e(int accountId, LedgerEntryType type, int minor, DateTime when,
          {int? categoryId, int allocated = 0, Currency c = uzs}) =>
      LedgerEntry(
        id: 0,
        accountId: accountId,
        type: type,
        amount: Money(minor, c),
        allocated: Money(allocated, c),
        occurredAt: when,
        categoryId: categoryId,
        incomeType: type == LedgerEntryType.income ? IncomeType.salary : null,
      );

  final entries = [
    e(1, LedgerEntryType.income, 5000000, DateTime(2026, 7, 5)),
    e(1, LedgerEntryType.expense, -200000, DateTime(2026, 7, 18), categoryId: 1),
    e(1, LedgerEntryType.expense, -50000, DateTime(2026, 7, 18), categoryId: 2),
    e(1, LedgerEntryType.expense, -70000, DateTime(2026, 7, 10), categoryId: 1),
    e(1, LedgerEntryType.expense, -999, DateTime(2026, 6, 30), categoryId: 1), // prev period
    e(1, LedgerEntryType.income, -0, DateTime(2026, 7, 5), c: usd), // other currency, skipped
  ];

  test('periodIncome sums income in the period, matching currency only', () {
    expect(periodIncome(entries, period, uzs), const Money(5000000, uzs));
  });

  test('periodExpense returns positive magnitude in the period', () {
    expect(periodExpense(entries, period, uzs), const Money(320000, uzs));
  });

  test('spentOn sums a single day', () {
    expect(spentOn(DateTime(2026, 7, 18), entries, uzs), const Money(250000, uzs));
  });

  test('categorySpent groups by category within the period', () {
    final m = categorySpent(entries, period, uzs);
    expect(m[1], const Money(270000, uzs));
    expect(m[2], const Money(50000, uzs));
  });

  test('totalsByCurrency sums balances per currency', () {
    const a1 = Account(id: 1, name: 'A', type: AccountType.cash,
        openingBalance: Money(1000000, uzs), icon: 'w', archived: false,
        role: AccountRole.spending);
    const a2 = Account(id: 2, name: 'B', type: AccountType.bankCard,
        openingBalance: Money(200, usd), icon: 'c', archived: false,
        role: AccountRole.spending);
    final es = [
      e(1, LedgerEntryType.expense, -300000, DateTime(2026, 7, 18)),
      e(2, LedgerEntryType.income, 50, DateTime(2026, 7, 18), c: usd),
    ];
    final totals = totalsByCurrency([a1, a2], es);
    expect(totals[uzs], const Money(700000, uzs));
    expect(totals[usd], const Money(250, usd));
  });
}
