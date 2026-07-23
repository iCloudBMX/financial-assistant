import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/ledger/summary_engine.dart';
import '../core/money/money.dart';
import '../core/reports/period_summary.dart';
import '../core/time/financial_period.dart';
import '../data/categories/category_model.dart';
import '../features/reports/category_report_view.dart';
import '../features/reports/report_data.dart';
import 'app_providers.dart';

final monthlyReportProvider = FutureProvider<MonthlyReport>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final settings = await ref.watch(settingsProvider.future);
  final accounts =
      await ref.watch(accountRepositoryProvider).list(includeArchived: false);
  final entries = await ref.watch(ledgerRepositoryProvider).allEntries();
  final categories = await ref.watch(categoriesProvider.future);
  final goals = await ref.watch(goalsProvider.future);

  final now = DateTime.now();
  final period = FinancialPeriod.containing(now, settings.periodStartDay);
  final prev = period.previous();
  final currency = settings.primaryCurrency;
  final mandatoryIds = {
    for (final c in categories)
      if (c.kind == CategoryKind.mandatory) c.id
  };

  // goal allocated this period: Σ positive contributions in-period across goals.
  // ponytail: N+1 over goals (one contributions() call each) — fine at MVP
  // scale; add a repo allContributions() if goal counts ever get large.
  final goalRepo = ref.watch(goalRepositoryProvider);
  var allocated = 0;
  for (final gwp in goals) {
    final cs = await goalRepo.contributions(gwp.goal.id);
    for (final c in cs) {
      if (c.amountMinor > 0 &&
          c.currencyCode == currency.code &&
          period.contains(c.occurredAt)) {
        allocated += c.amountMinor;
      }
    }
  }

  return MonthlyReport(
    current: buildMonthlySummary(
        accounts: accounts,
        entries: entries,
        mandatoryCategoryIds: mandatoryIds,
        period: period,
        currency: currency),
    previous: buildMonthlySummary(
        accounts: accounts,
        entries: entries,
        mandatoryCategoryIds: mandatoryIds,
        period: prev,
        currency: currency),
    goalAllocated: Money(allocated, currency),
    period: period,
    currency: currency,
  );
});

/// Reports ▸ Kategoriya: actual spend per category this period, share of
/// total expense, and spend in the previous period (for the trend chip).
/// No planned-budget/remaining/deviation — category budgets were removed.
final categoryReportProvider =
    FutureProvider<List<CategoryReportRow>>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final settings = await ref.watch(settingsProvider.future);
  final entries = await ref.watch(ledgerRepositoryProvider).allEntries();
  final categories = await ref.watch(categoriesProvider.future);

  final now = DateTime.now();
  final period = FinancialPeriod.containing(now, settings.periodStartDay);
  final prev = period.previous();
  final currency = settings.primaryCurrency;

  final spent = categorySpent(entries, period, currency);
  final prevSpentByCategory = categorySpent(entries, prev, currency);
  final total = periodExpense(entries, period, currency);

  final rows = <CategoryReportRow>[
    for (final c in categories)
      if ((spent[c.id]?.minorUnits ?? 0) > 0)
        CategoryReportRow(
          categoryId: c.id,
          name: c.name,
          icon: c.icon,
          spent: spent[c.id]!,
          shareBp: shareBp(spent[c.id]!, total),
          prevSpent: prevSpentByCategory[c.id] ?? Money.zero(currency),
        ),
  ];
  rows.sort((a, b) => b.spent.compareTo(a.spent));
  return rows;
});
