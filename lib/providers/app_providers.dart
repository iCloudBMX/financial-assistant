import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../core/allocation/allocation_plan.dart';
import '../core/goal/goal_engine.dart';
import '../core/ledger/account.dart';
import '../core/ledger/summary_engine.dart';
import '../core/limit/safe_limit_engine.dart';
import '../core/money/currency.dart';
import '../core/money/money.dart';
import '../core/mortgage/mortgage_engine.dart';
import '../core/time/financial_period.dart';
import '../data/accounts/account_repository.dart';
import '../data/allocation/allocation_plan_repository.dart';
import '../data/categories/category_model.dart';
import '../data/categories/category_repository.dart';
import '../data/db/app_database.dart';
import '../data/goals/goal_model.dart';
import '../data/goals/goal_repository.dart';
import '../data/ledger/ledger_repository.dart';
import '../data/meta/meta_model.dart';
import '../data/meta/meta_repository.dart';
import '../data/mortgage/mortgage_model.dart';
import '../data/mortgage/mortgage_repository.dart';
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

/// Every category (including archived), used to resolve category names for
/// history rows. Rebuilds when the ledger revision changes so a newly added
/// category appears without a manual refresh.
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(categoryRepositoryProvider).list(includeArchived: true);
});

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
  // Reuses the existing safe-limit/goal/mortgage/budget providers (not raw
  // repositories) so this stays the single place Home-related repository
  // reads are wired, per the Velora presentation-architecture boundary:
  // widgets only ever consume the resulting DashboardData.
  final safeLimit = await ref.watch(safeLimitProvider.future);
  final goals = await ref.watch(goalsProvider.future);
  final mortgages = await ref.watch(mortgagesProvider.future);
  return buildDashboard(
    accounts: accounts,
    entries: entries,
    primaryCurrency: settings.primaryCurrency,
    periodStartDay: settings.periodStartDay,
    now: DateTime.now(),
    safeLimit: safeLimit,
    primaryGoal: _selectPrimaryGoal(goals),
    mortgageSummary: _selectMortgageSummary(mortgages),
  );
});

/// Picks the Home "primary goal": the active goal with the highest priority
/// (critical > high > medium > low), tie-broken by the earliest target date
/// (goals with no deadline sort last), then by `sortOrder`.
PrimaryGoalSummary? _selectPrimaryGoal(List<GoalWithProgress> goals) {
  final active =
      goals.where((g) => g.goal.status == GoalStatus.active).toList()
        ..sort((a, b) {
          final byPriority =
              a.goal.priority.index.compareTo(b.goal.priority.index);
          if (byPriority != 0) return byPriority;
          final ad = a.goal.targetDate;
          final bd = b.goal.targetDate;
          if (ad != null && bd != null) {
            final byDate = ad.compareTo(bd);
            if (byDate != 0) return byDate;
          } else if (ad != null) {
            return -1;
          } else if (bd != null) {
            return 1;
          }
          return a.goal.sortOrder.compareTo(b.goal.sortOrder);
        });
  if (active.isEmpty) return null;
  final top = active.first;
  return PrimaryGoalSummary(
    id: top.goal.id,
    name: top.goal.name,
    icon: top.goal.icon,
    saved: top.progress.saved,
    target: top.progress.target,
    percentBp: top.progress.percentBp,
    remaining: top.progress.remaining,
  );
}

/// Picks the Home mortgage summary: the first mortgage, matching the
/// existing single-mortgage-card behavior in `MortgageSummaryCard`.
MortgageSummaryView? _selectMortgageSummary(
    List<MortgageWithProjection> mortgages) {
  if (mortgages.isEmpty) return null;
  final m = mortgages.first;
  final cur = CurrencyRegistry.byCode(m.mortgage.currencyCode);
  return MortgageSummaryView(
    id: m.mortgage.id,
    name: m.mortgage.name,
    currentPrincipal: Money(m.currentPrincipalMinor, cur),
    nextPaymentAmount: Money(m.mortgage.mandatoryPaymentMinor, cur),
    nextPaymentDate: m.mortgage.nextPaymentDate,
    completionBp: m.completionBp,
  );
}

final allocationPlanRepositoryProvider = Provider<AllocationPlanRepository>(
  (ref) => DriftAllocationPlanRepository(
    ref.watch(databaseProvider),
    ref.watch(accountRepositoryProvider),
  ),
);

final allocationPlanProvider = FutureProvider<AllocationPlan>((ref) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(allocationPlanRepositoryProvider).plan();
});

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => DriftGoalRepository(ref.watch(databaseProvider)),
);

/// A goal paired with its computed progress in the primary currency.
class GoalWithProgress {
  final Goal goal;
  final GoalProgress progress;
  const GoalWithProgress({required this.goal, required this.progress});
}

final goalsProvider = FutureProvider<List<GoalWithProgress>>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final settings = await ref.watch(settingsProvider.future);
  final currency = settings.primaryCurrency;
  final repo = ref.watch(goalRepositoryProvider);
  final goals = await repo.list();
  final now = DateTime.now();
  final out = <GoalWithProgress>[];
  for (final g in goals) {
    // TODO(multi-currency): goals in a non-primary currency are out of MVP scope.
    final savedMinor = await repo.savedFor(g.id);
    final progress = computeGoalProgress(GoalProgressInputs(
      saved: Money(savedMinor, currency),
      target: Money(g.targetAmountMinor, currency),
      startDate: g.startDate,
      targetDate: g.targetDate,
      asOf: now,
    ));
    out.add(GoalWithProgress(goal: g, progress: progress));
  }
  return out;
});

final goalContributionsProvider =
    FutureProvider.family<List<GoalContribution>, int>((ref, goalId) async {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(goalRepositoryProvider).contributions(goalId);
});

final mortgageRepositoryProvider = Provider<MortgageRepository>(
  (ref) => DriftMortgageRepository(
    ref.watch(databaseProvider),
    ref.watch(ledgerRepositoryProvider),
  ),
);

/// A mortgage paired with its derived balance, totals, and forward projection.
class MortgageWithProjection {
  final Mortgage mortgage;
  final int currentPrincipalMinor;
  final MortgageTotals totals;
  final MortgageProjection projection;
  final int completionBp; // 0..10000 vs initialLoan
  final int monthlyPrincipalMinor; // fixed differential principal (0 otherwise)
  const MortgageWithProjection({
    required this.mortgage,
    required this.currentPrincipalMinor,
    required this.totals,
    required this.projection,
    required this.completionBp,
    required this.monthlyPrincipalMinor,
  });
}

final mortgagesProvider =
    FutureProvider<List<MortgageWithProjection>>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final repo = ref.watch(mortgageRepositoryProvider);
  final mortgages = await repo.list();
  final now = DateTime.now();
  final out = <MortgageWithProjection>[];
  for (final m in mortgages) {
    // TODO(multi-currency): mortgages in a non-primary currency are out of MVP scope.
    final balance = await repo.currentPrincipalMinor(m.id);
    final totals = await repo.totals(m.id);
    // differential fixed principal ≈ opening / calendar-months of the term.
    // Captured once so the baseline projection AND any later recalc preview
    // (via MortgageWithProjection.monthlyPrincipalMinor) use identical inputs.
    final diffPrincipal = _differentialPrincipal(m);
    final projection = projectPayoff(
      currentPrincipalMinor: balance,
      annualRateBp: m.annualRateBp,
      type: m.paymentType,
      monthlyPaymentMinor: m.mandatoryPaymentMinor,
      monthlyPrincipalMinor: diffPrincipal,
      asOf: now,
      isApproximate: m.paymentType == PaymentType.custom,
    );
    final completionBp = m.initialLoanMinor <= 0
        ? 0
        : (((m.initialLoanMinor - balance) * 10000) ~/ m.initialLoanMinor)
            .clamp(0, 10000);
    out.add(MortgageWithProjection(
      mortgage: m,
      currentPrincipalMinor: balance,
      totals: totals,
      projection: projection,
      completionBp: completionBp,
      monthlyPrincipalMinor: diffPrincipal,
    ));
  }
  return out;
});

int _differentialPrincipal(Mortgage m) {
  if (m.paymentType != PaymentType.differential) return 0;
  final end = m.endDate;
  if (end == null) return 0;
  final months = (end.year * 12 + end.month) - (m.startDate.year * 12 + m.startDate.month);
  final n = months < 1 ? 1 : months;
  return m.openingPrincipalMinor ~/ n;
}

final mortgagePaymentsProvider =
    FutureProvider.family<List<MortgagePayment>, int>((ref, mortgageId) async {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(mortgageRepositoryProvider).payments(mortgageId);
});

final safeLimitProvider = FutureProvider<SafeLimit>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final settings = await ref.watch(settingsProvider.future);
  final currency = settings.primaryCurrency;
  final accounts =
      await ref.watch(accountRepositoryProvider).list(includeArchived: false);
  final entries = await ref.watch(ledgerRepositoryProvider).allEntries();
  final now = DateTime.now();
  final period = FinancialPeriod.containing(now, settings.periodStartDay);

  // Model A: the spendable pool is the summed ledger balance of the
  // Sarf-role (spending) cards in the primary currency. Reserve / Kredit /
  // Jamg'arma cards are excluded purely by role — there is no separate
  // reserve, goal, or mortgage subtraction in the daily-limit path anymore.
  final spending =
      accounts.where((a) => a.role == AccountRole.spending).toList();
  final pool =
      totalsByCurrency(spending, entries)[currency] ?? Money.zero(currency);

  // Whole days from today (date-floored) to the period's exclusive end; the
  // engine floors this at 1, so passing 0 on the last day is safe.
  final today = DateTime(now.year, now.month, now.day);
  final daysLeft = period.endExclusive.difference(today).inDays;

  return dailySpendLimit(
    spendablePool: pool,
    daysLeft: daysLeft,
    todaySpent: spentOn(now, entries, currency),
    hasSpendingAccounts: spending.isNotEmpty,
  );
});

