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
        openingBalance: Money(1000000, uzs), icon: 'w', archived: false, role: AccountRole.spending);
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
    expect(d.unallocatedEntryId, 1);
    expect(d.unallocatedEntryAmount, const Money(5000000, uzs));
    expect(d.primaryGoal, isNull);
    expect(d.mortgageSummary, isNull);
  });

  test(
      'buildDashboard picks the most recent income entry with an '
      'unallocated remainder, ignoring fully-allocated ones', () {
    final now = DateTime(2026, 7, 18, 12);
    const acc = Account(id: 1, name: 'A', type: AccountType.cash,
        openingBalance: Money(0, uzs), icon: 'w', archived: false, role: AccountRole.spending);
    final entries = [
      // Fully allocated — must not be picked even though it occurred later.
      LedgerEntry(id: 1, accountId: 1, type: LedgerEntryType.income,
          amount: const Money(3000000, uzs), allocated: const Money(3000000, uzs),
          occurredAt: DateTime(2026, 7, 10), incomeType: IncomeType.salary),
      // Older, still has a remainder.
      LedgerEntry(id: 2, accountId: 1, type: LedgerEntryType.income,
          amount: const Money(1000000, uzs), allocated: const Money(200000, uzs),
          occurredAt: DateTime(2026, 7, 1), incomeType: IncomeType.bonus),
      // Newest with a remainder — this is the one that should be picked.
      LedgerEntry(id: 3, accountId: 1, type: LedgerEntryType.income,
          amount: const Money(2000000, uzs), allocated: const Money(0, uzs),
          occurredAt: DateTime(2026, 7, 12), incomeType: IncomeType.freelance),
    ];
    final d = buildDashboard(
        accounts: [acc], entries: entries, primaryCurrency: uzs,
        periodStartDay: 1, now: now);
    expect(d.unallocatedEntryId, 3);
    expect(d.unallocatedEntryAmount, const Money(2000000, uzs));
    // Sum across every unallocated remainder, not just the picked entry.
    expect(d.undistributedFunds,
        const Money(800000 + 2000000, uzs)); // (1,000,000-200,000) + 2,000,000
  });

  test(
      'unallocatedEntryAmount is the remainder (amount − allocated), not the '
      'gross amount, when the winning entry is partially allocated', () {
    final now = DateTime(2026, 7, 18, 12);
    const acc = Account(id: 1, name: 'A', type: AccountType.cash,
        openingBalance: Money(0, uzs), icon: 'w', archived: false, role: AccountRole.spending);
    final entries = [
      // The most recent unallocated entry is itself PARTIALLY allocated:
      // gross 5,000,000 with 2,000,000 already allocated → remainder
      // 3,000,000. Home must allocate against the remainder, and the alert
      // must show the remainder, otherwise the prior partial allocation is
      // silently discarded.
      LedgerEntry(id: 9, accountId: 1, type: LedgerEntryType.income,
          amount: const Money(5000000, uzs), allocated: const Money(2000000, uzs),
          occurredAt: DateTime(2026, 7, 15), incomeType: IncomeType.salary),
    ];
    final d = buildDashboard(
        accounts: [acc], entries: entries, primaryCurrency: uzs,
        periodStartDay: 1, now: now);
    expect(d.unallocatedEntryId, 9);
    expect(d.unallocatedEntryAmount, const Money(3000000, uzs)); // NOT 5,000,000
  });

  test('buildDashboard passes through a provided primary goal and mortgage '
      'summary unchanged', () {
    final now = DateTime(2026, 7, 18, 12);
    const acc = Account(id: 1, name: 'A', type: AccountType.cash,
        openingBalance: Money(0, uzs), icon: 'w', archived: false, role: AccountRole.spending);
    const goal = PrimaryGoalSummary(
      id: 7,
      name: 'Zaxira',
      icon: 'flag',
      saved: Money(100000, uzs),
      target: Money(1000000, uzs),
      percentBp: 1000,
      remaining: Money(900000, uzs),
    );
    final mortgage = MortgageSummaryView(
      id: 3,
      name: 'Uy',
      currentPrincipal: const Money(50000000, uzs),
      nextPaymentAmount: const Money(2000000, uzs),
      nextPaymentDate: DateTime(2026, 8, 1),
      completionBp: 2500,
    );
    final d = buildDashboard(
        accounts: [acc], entries: const [], primaryCurrency: uzs,
        periodStartDay: 1, now: now,
        primaryGoal: goal, mortgageSummary: mortgage);
    expect(d.primaryGoal, same(goal));
    expect(d.mortgageSummary, same(mortgage));
  });
}
