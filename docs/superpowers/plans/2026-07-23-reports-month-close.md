# Reports & Month-close (SP5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Reports section (Monthly + Category + Goal + Mortgage views) and the soft-ceremony month-close flow (§16.1 summary + leftover distribution) over the existing engines, with a single new settings field marking the last closed period.

**Architecture:** Reports and the close summary are read-only views over a new pure `core/reports/period_summary.dart` engine plus the already-computed goal/mortgage providers. Month-close persists one field (`lastClosedPeriodStart`) and reuses the existing goal-contribute / mortgage-extra / allocation-transfer flows for leftover distribution — no new posting logic, no snapshots, no period locks.

**Tech Stack:** Flutter 3.44 + Drift 2.34 + Riverpod 3.3 + GoRouter 17. Pure-Dart `core/` (no `data/` imports). Money = integer minor units.

## Global Constraints

- Money is **integer minor units** everywhere; never a float. Seed editable money TextFields with `Money.formatNumber()` (NOT `.format()`) or an unedited save silently clears the value.
- `core/` must not import `data/` or `features/` — keep new engine pure (only `core/` imports).
- Run tests with `flutter test --concurrency=1` (default concurrency drops suites on this Windows box).
- Migrations are additive-only and guarded with `_hasColumn` before `addColumn` (a collapsed v1→vN pass may have already built the column via `createTable`).
- After any `tables.dart` change, regenerate: `dart run build_runner build --delete-conflicting-outputs`.
- UI copy is **Uzbek**. Reuse Velora components (`lib/ui/components/`: VeloraCard/Button/MoneyField/Sheet/Status/AsyncState) and match an existing screen's structure (e.g. `lib/features/goals/goals_screen.dart`). 48dp tap targets are enforced theme-wide.
- No new dependency.
- Providers invalidate off `ledgerRevisionProvider` (watch it in read-side providers; bump `ref.read(ledgerRevisionProvider.notifier).state++` after mutations).
- Sign convention: expense/transferOut negative, income/transferIn positive. `periodExpense` returns a positive magnitude.

---

### Task 1: Period-summary engine (pure)

**Files:**
- Create: `lib/core/reports/period_summary.dart`
- Test: `test/core/reports/period_summary_test.dart`

**Interfaces:**
- Consumes: `Account`, `AccountRole` (`core/ledger/account.dart`); `LedgerEntry`, `LedgerEntryType` (`core/ledger/ledger_entry.dart`); `accountBalance` (`core/ledger/balance_engine.dart`); `periodIncome`, `periodExpense` (`core/ledger/summary_engine.dart`); `FinancialPeriod` (`core/time/financial_period.dart`); `Money`, `Currency`.
- Produces:
  - `Money spendingLeftover(Iterable<Account> accounts, Iterable<LedgerEntry> entries, Currency currency)`
  - `class MonthlySummary { Money income, expense, mandatoryExpense, variableExpense, leftover; }`
  - `MonthlySummary buildMonthlySummary({required Iterable<Account> accounts, required Iterable<LedgerEntry> entries, required Set<int> mandatoryCategoryIds, required FinancialPeriod period, required Currency currency})`

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/core/reports/period_summary_test.dart`
Expected: FAIL — `period_summary.dart` / `spendingLeftover` not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/reports/period_summary.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/core/reports/period_summary_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/reports/period_summary.dart test/core/reports/period_summary_test.dart
git commit -m "feat(reports): pure period-summary engine (leftover + monthly split)"
```

---

### Task 2: Close-marker persistence (`lastClosedPeriodStart`, schema v8)

**Files:**
- Modify: `lib/data/db/tables.dart` (AppSettingsTable) — add column
- Modify: `lib/data/db/app_database.dart:24` — `schemaVersion` 7 → 8
- Modify: `lib/data/db/migrations.dart` — add `from < 8` branch
- Modify: `lib/data/settings/settings_model.dart` — add field + copyWith
- Modify: `lib/data/settings/settings_repository.dart` — map in read()/write()
- Test: `test/data/settings/last_closed_period_test.dart`

**Interfaces:**
- Produces: `AppSettings.lastClosedPeriodStart` (`DateTime?`), round-tripped by `DriftSettingsRepository`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lastClosedPeriodStart round-trips through the settings repo', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftSettingsRepository(db);
    final base = await repo.read();
    expect(base.lastClosedPeriodStart, isNull);
    await repo.write(base.copyWith(lastClosedPeriodStart: DateTime(2026, 7, 1)));
    final again = await repo.read();
    expect(again.lastClosedPeriodStart, DateTime(2026, 7, 1));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/data/settings/last_closed_period_test.dart`
Expected: FAIL — `copyWith` has no `lastClosedPeriodStart` param / getter missing.

- [ ] **Step 3: Write minimal implementation**

In `lib/data/db/tables.dart`, inside `AppSettingsTable` (after `allocationSourceAccountId`, line 30):
```dart
  DateTimeColumn get lastClosedPeriodStart => dateTime().nullable()();
```

In `lib/data/db/app_database.dart` change `int get schemaVersion => 7;` to `=> 8;`.

In `lib/data/db/migrations.dart`, add after the `from < 7` block (before the closing `);` of `onUpgrade`):
```dart
        if (from < 8) {
          // v7 -> v8: month-close marker. Additive, nullable. Guarded because a
          // collapsed v1->v8 pass may have built app_settings_table with the
          // full column set already (no drift versioned-schema CLI here).
          if (!await _hasColumn(
              m, 'app_settings_table', 'last_closed_period_start')) {
            await m.addColumn(db.appSettingsTable,
                db.appSettingsTable.lastClosedPeriodStart);
          }
        }
```

In `lib/data/settings/settings_model.dart`: add `final DateTime? lastClosedPeriodStart;` to the fields, `this.lastClosedPeriodStart,` to the constructor (optional/nullable), `DateTime? lastClosedPeriodStart,` to `copyWith` params, and `lastClosedPeriodStart: lastClosedPeriodStart ?? this.lastClosedPeriodStart,` to the returned `AppSettings`.

In `lib/data/settings/settings_repository.dart`: in `read()` where it builds `AppSettings`, add `lastClosedPeriodStart: row.lastClosedPeriodStart,`; in `write()`'s `AppSettingsTableCompanion`, add `lastClosedPeriodStart: Value(s.lastClosedPeriodStart),`.

Then regenerate drift:
```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/data/settings/last_closed_period_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/ test/data/settings/last_closed_period_test.dart
git commit -m "feat(month-close): persist lastClosedPeriodStart (schema v8)"
```

---

### Task 3: Monthly report provider + Reports screen (replaces placeholder)

**Files:**
- Create: `lib/features/reports/report_data.dart` (widget-free view-models)
- Create: `lib/providers/reports_providers.dart`
- Create: `lib/features/reports/reports_screen.dart`
- Modify: `lib/features/shell/routes.dart` — render `ReportsScreen` instead of `PlaceholderTab(title: 'Tahlil')` (import it; drop the `placeholder_tab` import if now unused)
- Test: `test/features/reports/reports_screen_test.dart`

**Interfaces:**
- Consumes: `settingsProvider`, `accountRepositoryProvider`, `ledgerRepositoryProvider`, `categoriesProvider`, `goalsProvider`, `ledgerRevisionProvider` (`lib/providers/app_providers.dart`); `buildMonthlySummary`, `MonthlySummary` (Task 1); `FinancialPeriod`.
- Produces:
  - `class MonthlyReport { MonthlySummary current; MonthlySummary previous; Money goalAllocated; FinancialPeriod period; Currency currency; }`
  - `final monthlyReportProvider = FutureProvider<MonthlyReport>(...)`
  - `class ReportsScreen extends ConsumerWidget`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:financial_assistant/features/reports/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Reuse the suite's seeded-container helper. Match the import other feature
// tests use (e.g. test/features/goals/*): a helper that returns a
// ProviderContainer wired to an in-memory AppDatabase with default seed data.
import '../../support/seeded_container.dart';

void main() {
  testWidgets('ReportsScreen renders the monthly report without error',
      (tester) async {
    final container = await seededContainer(); // seeds settings + default categories
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ReportsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ReportsScreen), findsOneWidget);
    // The monthly section header (Uzbek) is present.
    expect(find.text('Oylik hisobot'), findsOneWidget);
  });
}
```

> If the suite has no `seededContainer()` helper, mirror the exact setup an existing feature test uses (search `test/features/` for `ProviderContainer(` + `databaseProvider.overrideWith`). Use that pattern verbatim; do not invent a new harness.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/features/reports/reports_screen_test.dart`
Expected: FAIL — `ReportsScreen` not defined.

- [ ] **Step 3: Write minimal implementation**

`lib/features/reports/report_data.dart`:
```dart
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/reports/period_summary.dart';
import '../../core/time/financial_period.dart';

class MonthlyReport {
  final MonthlySummary current;
  final MonthlySummary previous;
  final Money goalAllocated;
  final FinancialPeriod period;
  final Currency currency;
  const MonthlyReport({
    required this.current,
    required this.previous,
    required this.goalAllocated,
    required this.period,
    required this.currency,
  });
}
```

`lib/providers/reports_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/money/money.dart';
import '../core/reports/period_summary.dart';
import '../core/time/financial_period.dart';
import '../data/categories/category_model.dart';
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
        accounts: accounts, entries: entries,
        mandatoryCategoryIds: mandatoryIds, period: period, currency: currency),
    previous: buildMonthlySummary(
        accounts: accounts, entries: entries,
        mandatoryCategoryIds: mandatoryIds, period: prev, currency: currency),
    goalAllocated: Money(allocated, currency),
    period: period,
    currency: currency,
  );
});
```

> Confirm `goalRepositoryProvider` exists in `app_providers.dart` (the goal-contribute flow uses it). If the exposed name differs, use the one `goal_controller.dart` reads.

`lib/features/reports/reports_screen.dart`: a `ConsumerWidget` with a `Scaffold(appBar: AppBar(title: Text('Tahlil')))` whose body is a `TabBar`/`TabBarView` (or a scroll view with sections) — start with just the Monthly tab; Tasks 4–5 add Category/Goal/Mortgage tabs. Watch `monthlyReportProvider` and render via the Velora async-state component. The monthly section shows a header `Text('Oylik hisobot')` and rows for income, expense, mandatory, variable, goal-allocated, leftover(undistributed), each with `Money.format()`, plus a "vs oldingi oy" delta line comparing `current` vs `previous` income/expense. **Mirror the layout of `lib/features/goals/goals_screen.dart`** (VeloraCard rows, AsyncState handling). Leave a `// TODO(SP5 Task 4/5)` where Category/Goal/Mortgage tabs slot in.

In `lib/features/shell/routes.dart` replace the reports branch builder body `child: PlaceholderTab(title: 'Tahlil')` with `child: ReportsScreen()` and add `import '../reports/reports_screen.dart';`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/features/reports/reports_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/reports/ lib/providers/reports_providers.dart lib/features/shell/routes.dart test/features/reports/reports_screen_test.dart
git commit -m "feat(reports): monthly report view replaces Tahlil placeholder"
```

---

### Task 4: Category report section (§15.4)

**Files:**
- Modify: `lib/providers/reports_providers.dart` — add `categoryReportProvider`
- Create: `lib/features/reports/category_report_view.dart`
- Modify: `lib/features/reports/reports_screen.dart` — add the Category tab
- Test: `test/features/reports/category_report_test.dart`

**Interfaces:**
- Consumes: `categorySpent` (`core/ledger/summary_engine.dart`), `categoriesProvider`, Task 3 providers.
- Produces:
  - `class CategoryReportRow { int categoryId; String name; String icon; Money spent; int shareBp; Money prevSpent; }`
  - `final categoryReportProvider = FutureProvider<List<CategoryReportRow>>(...)` (sorted desc by `spent`)

- [ ] **Step 1: Write the failing test** — pure share/sort logic via the provider is heavy to unit-test; instead test a small pure helper. Create `lib/features/reports/category_report_view.dart` with a pure top-level function and test it:

```dart
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/features/reports/category_report_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shareBp is basis points of total spend, rounded', () {
    expect(shareBp(Money(250000, CurrencyRegistry.uzs),
        Money(1000000, CurrencyRegistry.uzs)), 2500);
    expect(shareBp(Money(1, CurrencyRegistry.uzs),
        Money(0, CurrencyRegistry.uzs)), 0); // no divide-by-zero
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/features/reports/category_report_test.dart`
Expected: FAIL — `shareBp` not defined.

- [ ] **Step 3: Write minimal implementation**

In `lib/features/reports/category_report_view.dart` add:
```dart
int shareBp(Money part, Money total) {
  if (total.minorUnits <= 0) return 0;
  return ((part.minorUnits * 10000) / total.minorUnits).round();
}
```
Then the `categoryReportProvider` in `reports_providers.dart`: watch `ledgerRevisionProvider`, load settings/accounts/entries/categories, compute `categorySpent(entries, period, currency)` and `categorySpent(entries, prev, currency)`, total = `periodExpense(entries, period, currency)`, build one `CategoryReportRow` per category with `spent > 0`, `shareBp(spent, total)`, and `prevSpent` from the previous-period map (for the trend arrow). Sort desc by `spent`. Build the `CategoryReportView` widget (a `ConsumerWidget`) listing rows in VeloraCards: icon, name, spent (`Money.format()`), share %, and an up/down trend chip vs `prevSpent`. **No planned-budget / remaining / deviation columns** (category budgets were removed — see spec Conflict A). Add it as a second tab in `ReportsScreen`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/features/reports/category_report_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/reports/ lib/providers/reports_providers.dart test/features/reports/category_report_test.dart
git commit -m "feat(reports): category report (actual spend / share / trend)"
```

---

### Task 5: Goal & Mortgage report sections (§15.5, §13.8)

**Files:**
- Create: `lib/features/reports/goal_report_view.dart`
- Create: `lib/features/reports/mortgage_report_view.dart`
- Modify: `lib/features/reports/reports_screen.dart` — add Goal + Mortgage tabs
- Test: `test/features/reports/goal_mortgage_report_test.dart`

**Interfaces:**
- Consumes: `goalsProvider` → `List<GoalWithProgress>` (fields `goal`, `progress` with `saved/target/remaining/percentBp/projectedDate/requiredMonthly`); `mortgagesProvider` → `List<MortgageWithProjection>` (fields `mortgage`, `currentPrincipalMinor`, `totals` = `MortgageTotals{paidMinor, principalPaidMinor, interestPaidMinor, extraPaidMinor}`, `projection` = `MortgageProjection{payoffDate, monthsRemaining, totalRemainingInterestMinor, neverCloses}`, `completionBp`).
- Produces: `GoalReportView`, `MortgageReportView` (both `ConsumerWidget`).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:financial_assistant/features/reports/goal_report_view.dart';
import 'package:financial_assistant/features/reports/mortgage_report_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/seeded_container.dart';

void main() {
  testWidgets('goal & mortgage report views render empty-state without error',
      (tester) async {
    final container = await seededContainer();
    addTearDown(container.dispose);
    for (final view in const [GoalReportView(), MortgageReportView()]) {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: view)),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/features/reports/goal_mortgage_report_test.dart`
Expected: FAIL — views not defined.

- [ ] **Step 3: Write minimal implementation**

`GoalReportView` (`ConsumerWidget`): watch `goalsProvider`; for each `GoalWithProgress` show a VeloraCard with name/icon, progress bar (`percentBp`), `saved`/`target`/`remaining` (`Money.format()`), and forecast (`progress.projectedDate` / `progress.requiredMonthly` when non-null). Empty state: an Uzbek "no goals yet" message. (This re-surfaces the already-computed engine output; the per-goal history detail stays on the existing goal-detail screen.)

`MortgageReportView` (`ConsumerWidget`): watch `mortgagesProvider`; for each `MortgageWithProjection` show a VeloraCard with: current principal (`currentPrincipalMinor`), principal paid + interest paid + extra paid (from `totals`), completion % (`completionBp`), and planned payoff date (`projection.payoffDate`, or an Uzbek "never closes at this rate" when `projection.neverCloses`). Empty state message.
```dart
// ponytail: §13.8 month-by-month balance table + estimated-interest-saved/
// term-reduction are DEFERRED — the amortization loop keeps no schedule and
// interest-saved needs a scenario baseline. Summary figures below are all
// already computed on MortgageWithProjection. Add the schedule table + a
// scenario compare when a mortgage-detail report is requested.
```
Add both as tabs 3 and 4 in `ReportsScreen` (tab order: Oylik, Kategoriya, Maqsad, Ipoteka).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/features/reports/goal_mortgage_report_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/reports/ test/features/reports/goal_mortgage_report_test.dart
git commit -m "feat(reports): thin goal & mortgage report views"
```

---

### Task 6: Month-close summary screen + unclosed-period CTA

**Files:**
- Create: `lib/features/month_close/month_close_data.dart` (view-model + closeable-period logic)
- Create: `lib/providers/month_close_providers.dart`
- Create: `lib/features/month_close/month_close_screen.dart`
- Modify: `lib/features/reports/reports_screen.dart` — show the CTA banner when a period is closeable
- Test: `test/features/month_close/closeable_period_test.dart`

**Interfaces:**
- Consumes: `FinancialPeriod`, `buildMonthlySummary`/`spendingLeftover` (Task 1), `settingsProvider`, `settingsRepositoryProvider`, `ledgerRevisionProvider`, Task 3 loads.
- Produces:
  - `FinancialPeriod? closeablePeriod(DateTime now, int startDay, DateTime? lastClosedStart)` — the just-elapsed period if not yet closed, else null.
  - `class MonthCloseData { FinancialPeriod period; MonthlySummary summary; Money goalAllocated; }`
  - `final monthCloseProvider = FutureProvider<MonthCloseData?>(...)`
  - `final closePeriodProvider = Provider<Future<void> Function(DateTime periodStart)>(...)` (or a small Notifier) that writes `lastClosedPeriodStart` and invalidates settings.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:financial_assistant/features/month_close/month_close_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const startDay = 1;
  // now is 5 Aug 2026 -> current period Aug 1..Sep 1; just-elapsed = Jul 1..Aug 1.
  final now = DateTime(2026, 8, 5);

  test('closeablePeriod returns the just-elapsed period when never closed', () {
    final p = closeablePeriod(now, startDay, null);
    expect(p!.start, DateTime(2026, 7, 1));
    expect(p.endExclusive, DateTime(2026, 8, 1));
  });

  test('closeablePeriod is null once that period is already closed', () {
    expect(closeablePeriod(now, startDay, DateTime(2026, 7, 1)), isNull);
  });

  test('closeablePeriod still offers an older unclosed period', () {
    // last closed was June -> July is still closeable.
    final p = closeablePeriod(now, startDay, DateTime(2026, 6, 1));
    expect(p!.start, DateTime(2026, 7, 1));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/features/month_close/closeable_period_test.dart`
Expected: FAIL — `closeablePeriod` not defined.

- [ ] **Step 3: Write minimal implementation**

In `lib/features/month_close/month_close_data.dart`:
```dart
import '../../core/money/money.dart';
import '../../core/reports/period_summary.dart';
import '../../core/time/financial_period.dart';

/// The most recent elapsed period that has not yet been closed, or null.
/// "Elapsed" = its endExclusive is at/behind [now]. The candidate is the
/// period just before the one containing [now]. Considered closed when
/// [lastClosedStart] is at or after the candidate's start.
FinancialPeriod? closeablePeriod(
    DateTime now, int startDay, DateTime? lastClosedStart) {
  final candidate = FinancialPeriod.containing(now, startDay).previous();
  if (lastClosedStart != null && !lastClosedStart.isBefore(candidate.start)) {
    return null;
  }
  return candidate;
}

class MonthCloseData {
  final FinancialPeriod period;
  final MonthlySummary summary;
  final Money goalAllocated;
  const MonthCloseData({
    required this.period,
    required this.summary,
    required this.goalAllocated,
  });
}
```

`month_close_providers.dart`: `monthCloseProvider` computes `closeablePeriod`; if null returns null (no banner). Otherwise loads accounts/entries/categories/goals (same as Task 3), builds `MonthlySummary` for that period via `buildMonthlySummary`, and `goalAllocated` for that period (same fold as Task 3 — extract the fold into a shared helper in `reports_providers.dart` to stay DRY). `closePeriodProvider` returns a function:
```dart
final closePeriodProvider =
    Provider<Future<void> Function(DateTime)>((ref) => (periodStart) async {
  final repo = ref.read(settingsRepositoryProvider);
  final current = await repo.read();
  await repo.write(current.copyWith(lastClosedPeriodStart: periodStart));
  ref.invalidate(settingsProvider);
  ref.read(ledgerRevisionProvider.notifier).state++;
});
```

`month_close_screen.dart` (`ConsumerWidget`): watch `monthCloseProvider`; render the §16.1 summary (income, expense, saved-or-over = leftover with sign-aware Uzbek label "tejaldi"/"oshib ketdi", goal-allocated, undistributed = leftover). A "Distribute leftover" section is added in Task 7. A primary "Oyni yopish" button calls `closePeriodProvider`'s function with `period.start`, then pops. Reuse Velora async-state + button components.

In `ReportsScreen`, watch `monthCloseProvider`; when it has a non-null value, show a highlighted VeloraCard banner at the top ("Iyul oyini yopish vaqti keldi") that navigates to `MonthCloseScreen` (push via `Navigator` or a GoRoute — add a plain `MaterialPageRoute` push to keep routing changes minimal).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/features/month_close/closeable_period_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/month_close/ lib/providers/month_close_providers.dart lib/features/reports/reports_screen.dart test/features/month_close/closeable_period_test.dart
git commit -m "feat(month-close): §16.1 summary screen + unclosed-period CTA"
```

---

### Task 7: Leftover-distribution chooser (§16.2)

**Files:**
- Modify: `lib/features/goals/goal_contribute_sheet.dart` — add `Money? initialAmount` param
- Modify: `lib/features/mortgage/mortgage_extra_payment_sheet.dart` — add `Money? initialAmount` param
- Modify: `lib/features/month_close/month_close_screen.dart` — add the destination chooser
- Test: `test/features/month_close/distribution_chooser_test.dart`

**Interfaces:**
- Consumes: `showGoalContributeSheet(context, ref, {required int goalId, bool withdraw, Money? initialAmount})`; `showMortgageExtraPaymentSheet(context, ref, int mortgageId, {Money? initialAmount})`; `goalsProvider`, `mortgagesProvider`; `AllocationPlanScreen` route for the reserve path.
- Produces: the distribution UI in `MonthCloseScreen`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/features/goals/goal_contribute_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/seeded_container.dart';

void main() {
  testWidgets('goal contribute sheet prefills the initial amount', (tester) async {
    final container = await withOneGoal(); // seed a single goal; see helper note
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) => Scaffold(
          body: Center(child: ElevatedButton(
            onPressed: () => showGoalContributeSheet(context, ref,
                goalId: 1, initialAmount: Money(750000, CurrencyRegistry.uzs)),
            child: const Text('open'))))),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // formatNumber for UZS groups thousands with spaces.
    expect(find.text('750 000'), findsOneWidget);
  });
}
```

> `withOneGoal()` = the seeded container plus one inserted goal (id 1). If no such helper exists, seed via the goal repository/controller exposed by the container, mirroring an existing goals feature test.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/features/month_close/distribution_chooser_test.dart`
Expected: FAIL — `showGoalContributeSheet` has no `initialAmount` param.

- [ ] **Step 3: Write minimal implementation**

In `goal_contribute_sheet.dart`: add `Money? initialAmount` to `showGoalContributeSheet` and pass to `_ContributeSheet`; in `_ContributeSheetState.initState`, if `widget.initialAmount != null` set `_amount.text = widget.initialAmount!.formatNumber();`. Same edit in `mortgage_extra_payment_sheet.dart` for `showMortgageExtraPaymentSheet` / `_ExtraSheet`.

In `MonthCloseScreen`, add a "Qoldiqni taqsimlash" section under the summary showing the live leftover and four destination actions (each a 48dp VeloraButton/tile):
- **Maqsadga** → pick a goal (simple list/dialog from `goalsProvider`), then `showGoalContributeSheet(context, ref, goalId: id, initialAmount: leftover)`.
- **Ipotekaga** → pick a mortgage from `mortgagesProvider`, then `showMortgageExtraPaymentSheet(context, ref, mortgageId, initialAmount: leftover)`.
- **Zaxiraga** → `context.goNamed(RouteNames.plan)` (the existing card-based allocation/transfer screen). ponytail: reuse the allocation plan rather than a new transfer sheet.
- **Keyingi oyga** → dismiss (no-op; money stays in spending accounts).

After any sheet returns, the screen rebuilds from `monthCloseProvider` (leftover recomputed from live balances). `leftover` for prefill = `data.summary.leftover` clamped to `>= 0` (don't prefill a negative).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/features/month_close/distribution_chooser_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/goals/goal_contribute_sheet.dart lib/features/mortgage/mortgage_extra_payment_sheet.dart lib/features/month_close/month_close_screen.dart test/features/month_close/distribution_chooser_test.dart
git commit -m "feat(month-close): leftover-distribution chooser reuses existing sheets"
```

---

### Task 8: Golden gallery entries

**Files:**
- Create: `test/goldens/reports_month_close_golden_test.dart`
- Create: `test/goldens/baselines/*.png` (generated via `--update-goldens`)

**Interfaces:**
- Consumes: `pumpVelora`, `phone390` (`test/support/velora_test_app.dart`, `test/support/golden_devices.dart`); the seeded-container helper; `ReportsScreen`, `MonthCloseScreen`.

- [ ] **Step 1: Write the golden test** — mirror `test/goldens/existing_flow_gallery_test.dart` structure exactly:

```dart
// group per screen; build seeded container, pumpVelora at phone390 light,
// expect(tester.takeException(), isNull), then matchesGoldenFile(...).
// Screens: ReportsScreen (default Oylik tab), and each tab if easily switched;
// MonthCloseScreen with a closeable period seeded.
```
Register at least: `baselines/reports-monthly-light-390.png`, `baselines/month-close-light-390.png`.

- [ ] **Step 2: Generate baselines**

Run: `flutter test --concurrency=1 --update-goldens test/goldens/reports_month_close_golden_test.dart`
Expected: PASS; new PNGs written under `test/goldens/baselines/`.

- [ ] **Step 3: Verify goldens pass on re-run**

Run: `flutter test --concurrency=1 test/goldens/reports_month_close_golden_test.dart`
Expected: PASS.

> Known env caveat (see memory `toolchain-gotchas`): some full-screen goldens fail locally for environmental reasons. If a new baseline fails only on pixel drift (not layout), record it for CI re-baseline rather than chasing it here.

- [ ] **Step 4: Commit**

```bash
git add test/goldens/reports_month_close_golden_test.dart test/goldens/baselines/
git commit -m "test(reports): golden baselines for reports + month-close"
```

---

### Final: full suite + analyze

- [ ] Run `flutter analyze` — expect clean (fix any new warnings).
- [ ] Run `flutter test --concurrency=1` — expect all green except the pre-existing environmental golden drift noted in memory.
- [ ] Update the `project-overview` memory: SP5 built; note deferrals (§15.6 filtering, daily/weekly report screens, §13.8 month-by-month table + interest-saved, OS notifications §17, atomic multi-target splitter).
