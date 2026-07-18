import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/ledger/account.dart';
import 'package:financial_assistant/core/ledger/ledger_entry.dart';
import 'package:financial_assistant/features/home/dashboard_data.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  test('buildDashboard aggregates balance, month totals, today, undistributed', () {
    final now = DateTime(2026, 7, 18, 12);
    const acc = Account(id: 1, name: 'A', type: AccountType.cash,
        openingBalance: Money(1000000, uzs), icon: 'w', archived: false);
    final entries = [
      LedgerEntry(id: 1, accountId: 1, type: LedgerEntryType.income,
          amount: const Money(5000000, uzs), allocated: const Money(0, uzs),
          occurredAt: DateTime(2026, 7, 3), incomeType: IncomeType.salary),
      LedgerEntry(id: 2, accountId: 1, type: LedgerEntryType.expense,
          amount: const Money(-200000, uzs), allocated: const Money(0, uzs),
          occurredAt: now, categoryId: 1),
    ];
    final d = buildDashboard(
        accounts: [acc], entries: entries, primaryCurrency: uzs,
        periodStartDay: 1, now: now);
    expect(d.totals[uzs], const Money(5800000, uzs)); // 1,000,000 + 5,000,000 - 200,000
    expect(d.monthIncome, const Money(5000000, uzs));
    expect(d.monthExpense, const Money(200000, uzs));
    expect(d.todaySpent, const Money(200000, uzs));
    expect(d.undistributedFunds, const Money(5000000, uzs));
    expect(d.primaryCurrency, uzs);
  });
}
