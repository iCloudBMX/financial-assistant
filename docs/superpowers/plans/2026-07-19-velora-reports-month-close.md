# Velora Reports and Month-Close Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement PRD-complete daily, weekly, monthly, category, goal, and mortgage reports plus atomic financial-period close and next-period planning.

**Architecture:** Pure Dart report/close engines derive immutable summaries; Drift schema v6 stores only close records and allocations. Repositories coordinate atomic commits, Riverpod exposes view models, and Flutter screens render approved Velora report and month-close mockups.

**Tech Stack:** Dart pure engines, Drift schema v6, Riverpod, Flutter charts built with accessible CustomPainter/SVG-equivalent widgets, widget/golden/performance tests.

## Global Constraints

- Execute after the UI Foundation and Existing Financial Flows plans.
- Reports derive from ledger truth and never store duplicated totals.
- Closed-period commits, leftover allocations, and next-period creation are one database transaction.
- Filters: date range, account, category, transaction type, goal, mortgage.
- A monthly report over 10,000 transactions opens in under two seconds.
- Charts have visible values and semantic text equivalents.

---

### Task 1: Build pure report models and engine

**Files:**
- Create: `lib/core/report/report_models.dart`
- Create: `lib/core/report/report_engine.dart`
- Create: `test/core/report/report_engine_test.dart`

**Interfaces:**
- Produces: `DailyReport`, `WeeklyReport`, `MonthlyReport`, `CategoryReport`, `GoalReport`, `MortgageReport`, `ReportFilter`.

- [ ] Write table-driven tests for PRD §15 fields, previous-period comparison, category share/trend, goal contribution history, and mortgage principal/interest/extra series.

```dart
final report = buildMonthlyReport(entries: entries, period: july, currency: uzs,
  goalContributions: goals, mortgagePayments: payments);
expect(report.income.minorUnits, 12500000);
expect(report.expense.minorUnits, 10660000);
expect(report.savings.minorUnits, 1840000);
```

- [ ] Run `flutter test test/core/report/report_engine_test.dart`; expect missing-library failure.
- [ ] Implement immutable models and single-pass aggregation keyed by category/account/date. Reject mixed-currency aggregation with `CurrencyFailure` instead of conversion.
- [ ] Run the report engine tests; expect all field and filter assertions to pass.
- [ ] Commit with `git add lib/core/report test/core/report && git commit -m "feat: add pure reporting engine"`.

### Task 2: Add schema v6 period-close data

**Files:**
- Modify: `lib/data/db/tables.dart`
- Modify: `lib/data/db/app_database.dart`
- Modify: `lib/data/db/migrations.dart`
- Create: `test/data/db/schema_v6_migration_test.dart`
- Create: `test/drift_schemas/drift_schema_v6.json`

**Interfaces:**
- Produces tables `financial_period_closes` and `period_close_allocations` with unique period start and foreign-key cascade.

- [ ] Add a migration test opening a v5 fixture, upgrading to v6, and proving all existing accounts, transactions, goals, and mortgages survive.
- [ ] Run `flutter test test/data/db/schema_v6_migration_test.dart`; expect schema/table failure.
- [ ] Add both tables, set `schemaVersion => 6`, create them only in the 5→6 step, and export the Drift schema snapshot.
- [ ] Run all `test/data/db` tests; expect v1→v6 through v5→v6 paths to pass.
- [ ] Commit with `git add lib/data/db test/data/db test/drift_schemas && git commit -m "feat: add period-close schema v6"`.

### Task 3: Implement report and month-close repositories

**Files:**
- Create: `lib/data/reports/report_repository.dart`
- Create: `lib/data/month_close/month_close_model.dart`
- Create: `lib/data/month_close/month_close_repository.dart`
- Create: `test/data/reports/report_repository_test.dart`
- Create: `test/data/month_close/month_close_repository_test.dart`

**Interfaces:**
- `ReportRepository.load(ReportFilter) -> Future<ReportBundle>`.
- `MonthCloseRepository.preview(FinancialPeriod) -> Future<MonthClosePreview>`.
- `MonthCloseRepository.close(MonthCloseCommand) -> Future<Result<int>>`.
- `MonthCloseRepository.reopen(int closeId) -> Future<Result<void>>`.

- [ ] Write in-memory Drift tests for preview totals, draft blocking, exact leftover balance, atomic close, forced-failure rollback, copied budgets/obligations, and reopen.
- [ ] Run repository tests; expect missing implementation failure.
- [ ] Implement queries and wrap close record + allocations + next-period creation in `db.transaction`. Validate `sum(allocations) == leftoverMinor` before any write.
- [ ] Run repository plus full DB tests; expect no partial rows after forced failure.
- [ ] Commit with `git add lib/data/reports lib/data/month_close test/data && git commit -m "feat: add reports and atomic month close repositories"`.

### Task 4: Wire Riverpod report and close view models

**Files:**
- Create: `lib/features/reports/report_controller.dart`
- Create: `lib/features/month_close/month_close_controller.dart`
- Modify: `lib/providers/app_providers.dart`
- Create: `test/features/reports/report_controller_test.dart`
- Create: `test/features/month_close/month_close_controller_test.dart`

**Interfaces:**
- Produces `reportControllerProvider`, `monthCloseControllerProvider`, `ReportViewState`, `MonthCloseViewState`.

- [ ] Write provider tests for filter changes, local loading preservation, close validation, typed failures, and revision invalidation.
- [ ] Run tests and verify missing providers.
- [ ] Implement controllers that call repositories, preserve prior data during refresh, and increment `ledgerRevisionProvider` only after successful close/reopen.
- [ ] Run provider tests; expect PASS with no raw exceptions in state.
- [ ] Commit with `git add lib/features/reports lib/features/month_close lib/providers test/features && git commit -m "feat: wire report and month-close state"`.

### Task 5: Build Tahlil reports UI

**Files:**
- Create: `lib/features/reports/reports_screen.dart`
- Create: `lib/features/reports/report_filter_sheet.dart`
- Create: `lib/features/reports/report_chart.dart`
- Modify: `lib/features/shell/app_shell.dart`
- Create: `test/features/reports/reports_screen_test.dart`
- Create: `test/goldens/reports_golden_test.dart`

**Interfaces:**
- Replaces the temporary Reports tab with `ReportsScreen`.

- [ ] Add widget tests for six report modes, filter sheet, directly labeled chart values, semantic summaries, empty/error/loading/offline states, and previous-period comparison.
- [ ] Run the report screen test; expect missing widget failure.
- [ ] Build the approved Tahlil layout using Velora cards/status components. Keep charts presentation-only and expose the same data in semantics and compact text rows.
- [ ] Run widget/golden tests at 320 px, dark theme, and 200% scale; expect no clipping.
- [ ] Commit with `git add lib/features/reports lib/features/shell test/features/reports test/goldens && git commit -m "feat: add Velora reports screens"`.

### Task 6: Build month-close, leftover allocation, and next-month screens

**Files:**
- Create: `lib/features/month_close/month_close_screen.dart`
- Create: `lib/features/month_close/leftover_allocation_screen.dart`
- Create: `lib/features/month_close/next_period_plan_screen.dart`
- Modify: `lib/features/shell/routes.dart`
- Create: `test/features/month_close/month_close_screen_test.dart`
- Create: `test/goldens/month_close_golden_test.dart`

**Interfaces:**
- Routes: `/month-close`, `/month-close/allocation`, `/month-close/next-plan`.

- [ ] Write tests for checklist blocking, constructive draft action, allocation equation, disabled unbalanced CTA, consequence warning, atomic success, and explicit reopen.
- [ ] Run month-close widget tests; expect route/widget failure.
- [ ] Implement the three-screen flow exactly as approved, using `VeloraMoneyField` for editable allocations and one CTA per screen.
- [ ] Run widget/golden tests plus repository rollback tests; expect PASS.
- [ ] Commit with `git add lib/features/month_close lib/features/shell test/features/month_close test/goldens && git commit -m "feat: add Velora month-close flow"`.

### Task 7: Prove report performance and AC 15

**Files:**
- Create: `test/performance/report_10000_test.dart`
- Create: `integration_test/reports_month_close_flow_test.dart`

**Interfaces:**
- Produces timing and end-to-end evidence for reports and month-close.

- [ ] Generate a deterministic 10,000-entry fixture and time `buildMonthlyReport`; assert below two seconds in profile/device verification and record raw duration.
- [ ] Add an integration flow from Tahlil → month close → allocation → next plan → confirmed new period.
- [ ] Run `flutter test test/performance/report_10000_test.dart` and device `flutter test integration_test/reports_month_close_flow_test.dart`.
- [ ] Run `flutter analyze && flutter test`; expect 0 issues and all tests green.
- [ ] Commit with `git add test/performance integration_test && git commit -m "test: prove reports and month-close acceptance"`.
