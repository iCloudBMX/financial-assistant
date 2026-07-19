import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../core/allocation/allocation_models.dart';
import '../core/budget/category_budget_engine.dart';
import '../core/ledger/summary_engine.dart';
import '../core/limit/safe_limit_engine.dart';
import '../core/money/money.dart';
import '../core/time/financial_period.dart';
import '../core/time/weekday.dart';
import '../data/accounts/account_repository.dart';
import '../data/allocation/allocation_repository.dart';
import '../data/budget/budget_repository.dart';
import '../data/categories/category_model.dart';
import '../data/categories/category_repository.dart';
import '../data/db/app_database.dart';
import '../data/ledger/ledger_repository.dart';
import '../data/meta/meta_model.dart';
import '../data/meta/meta_repository.dart';
import '../data/recurring/recurring_repository.dart';
import '../data/settings/settings_model.dart';
import '../data/settings/settings_repository.dart';
import '../features/home/dashboard_data.dart';
import '../features/security/app_lock_controller.dart';

/// Overridden in the composition root with the opened database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => DriftSettingsRepository(ref.watch(databaseProvider)),
);

final metaRepositoryProvider = Provider<MetaRepository>(
  (ref) => DriftMetaRepository(ref.watch(databaseProvider)),
);

final settingsProvider = FutureProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).read(),
);

final metaProvider = FutureProvider<AppMeta>(
  (ref) => ref.watch(metaRepositoryProvider).read(),
);

/// Device-backed app-lock controller (PIN hash + biometric), constructed
/// once at the composition root and reused across rebuilds so unlocking
/// doesn't get reset by unrelated provider changes.
final appLockControllerProvider = Provider<AppLockController>(
  (ref) => AppLockController(const SecureSecretStore()),
);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => DriftAccountRepository(ref.watch(databaseProvider)),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => DriftCategoryRepository(ref.watch(databaseProvider)),
);

final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => DriftLedgerRepository(
    ref.watch(databaseProvider),
    ref.watch(accountRepositoryProvider),
  ),
);

final recurringIncomeRepositoryProvider = Provider<RecurringIncomeRepository>(
  (ref) => DriftRecurringIncomeRepository(ref.watch(databaseProvider)),
);

/// Bumped by every ledger/account mutation. Read-side providers watch it so
/// they recompute after any change — without mutating controllers having to
/// name each other (which would create forward references across tasks).
final ledgerRevisionProvider = StateProvider<int>((ref) => 0);

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final settings = await ref.watch(settingsProvider.future);
  final accounts =
      await ref.watch(accountRepositoryProvider).list(includeArchived: false);
  final entries = await ref.watch(ledgerRepositoryProvider).allEntries();
  return buildDashboard(
    accounts: accounts,
    entries: entries,
    primaryCurrency: settings.primaryCurrency,
    periodStartDay: settings.periodStartDay,
    now: DateTime.now(),
  );
});

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => DriftBudgetRepository(ref.watch(databaseProvider)),
);

final allocationRepositoryProvider = Provider<AllocationRepository>(
  (ref) => DriftAllocationRepository(ref.watch(databaseProvider)),
);

final allocationTemplateProvider = FutureProvider<AllocationTemplate>((ref) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(allocationRepositoryProvider).template();
});

/// A category with its spend and status for the month and the week.
class CategoryBudgetView {
  final Category category;
  final Money monthSpent;
  final Money weekSpent;
  final CategoryLimitStatus monthStatus;
  final CategoryLimitStatus weekStatus;
  const CategoryBudgetView({
    required this.category,
    required this.monthSpent,
    required this.weekSpent,
    required this.monthStatus,
    required this.weekStatus,
  });
}

final categoryBudgetsProvider =
    FutureProvider<List<CategoryBudgetView>>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final settings = await ref.watch(settingsProvider.future);
  final currency = settings.primaryCurrency;
  final cats = await ref.watch(budgetRepositoryProvider).categoriesWithBudgets();
  final entries = await ref.watch(ledgerRepositoryProvider).allEntries();
  final now = DateTime.now();
  final period = FinancialPeriod.containing(now, settings.periodStartDay);
  final weekStart = startOfWeek(now, settings.weekStartIso);
  final weekEnd = weekStart.add(const Duration(days: 7));

  final monthByCat = categorySpent(entries, period, currency);
  final weekByCat = categorySpent(
    entries,
    FinancialPeriod(weekStart, weekEnd, settings.periodStartDay),
    currency,
  );

  Money zero() => Money.zero(currency);
  Money? asMoney(int? minor) => minor == null ? null : Money(minor, currency);

  return cats.map((c) {
    final ms = monthByCat[c.id] ?? zero();
    final ws = weekByCat[c.id] ?? zero();
    return CategoryBudgetView(
      category: c,
      monthSpent: ms,
      weekSpent: ws,
      monthStatus: categoryStatus(ms, asMoney(c.monthlyLimitMinor)),
      weekStatus: categoryStatus(ws, asMoney(c.weeklyLimitMinor)),
    );
  }).toList();
});

final safeLimitProvider = FutureProvider<SafeLimit>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final settings = await ref.watch(settingsProvider.future);
  final currency = settings.primaryCurrency;
  final accounts =
      await ref.watch(accountRepositoryProvider).list(includeArchived: false);
  final entries = await ref.watch(ledgerRepositoryProvider).allEntries();
  final cats = await ref.watch(budgetRepositoryProvider).categoriesWithBudgets(
        includeArchived: true,
      );
  final now = DateTime.now();
  final period = FinancialPeriod.containing(now, settings.periodStartDay);

  final variableIds = cats
      .where((c) => c.kind == CategoryKind.variable)
      .map((c) => c.id)
      .toSet();
  final byCat = categorySpent(entries, period, currency);
  var variableSpentMinor = 0;
  byCat.forEach((catId, spent) {
    if (variableIds.contains(catId)) variableSpentMinor += spent.minorUnits;
  });

  final totals = totalsByCurrency(accounts, entries);
  final totalAvailable = totals[currency] ?? Money.zero(currency);

  final inputs = SafeLimitInputs(
    variableBudget: settings.variableBudget,
    variableSpent: Money(variableSpentMinor, currency),
    manualBuffer: settings.safetyBuffer,
    totalAvailable: totalAvailable,
    minReserve: settings.minReserve.currency == currency
        ? settings.minReserve
        : Money.zero(currency),
    goalReserves: Money.zero(currency), // SP3 supplies real values
    unpaidMandatory: Money.zero(currency), // SP4 supplies real values
    todaySpent: spentOn(now, entries, currency),
    period: period,
    asOf: now,
  );
  return dailySafeLimit(inputs);
});

final weeklySafeLimitProvider = FutureProvider<WeeklySafeLimit>((ref) async {
  final daily = await ref.watch(safeLimitProvider.future);
  final settings = await ref.watch(settingsProvider.future);
  final currency = settings.primaryCurrency;
  final entries = await ref.watch(ledgerRepositoryProvider).allEntries();
  final cats = await ref.watch(budgetRepositoryProvider).categoriesWithBudgets(
        includeArchived: true,
      );
  final now = DateTime.now();
  final weekStart = startOfWeek(now, settings.weekStartIso);
  final weekEnd = weekStart.add(const Duration(days: 7));
  final today = DateTime(now.year, now.month, now.day);
  final daysLeftInWeek = weekEnd.difference(today).inDays.clamp(1, 7);

  final variableIds = cats
      .where((c) => c.kind == CategoryKind.variable)
      .map((c) => c.id)
      .toSet();
  final weekByCat = categorySpent(
    entries,
    FinancialPeriod(weekStart, weekEnd, settings.periodStartDay),
    currency,
  );
  var weekVarMinor = 0;
  weekByCat.forEach((catId, spent) {
    if (variableIds.contains(catId)) weekVarMinor += spent.minorUnits;
  });

  return weeklySafeLimit(daily,
      daysLeftInWeek: daysLeftInWeek,
      weeklySpent: Money(weekVarMinor, currency));
});
