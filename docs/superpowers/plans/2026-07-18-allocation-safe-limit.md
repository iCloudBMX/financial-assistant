# Allocation & Safe-Limit Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build sub-project 2 of 7 — category budgets with safe/near/over status (§10.3–10.4), the daily + weekly safe-limit engine (§11), and income allocation across generic buckets via one reusable template (§8, §7.2).

**Architecture:** Three pure-Dart engines under `core/` own all the math and are exhaustively unit-tested with no Drift or Flutter: `core/budget` (per-category limit status), `core/limit` (daily/weekly safe limit), `core/allocation` (split an income across buckets). Buckets are identified by a **string key**; SP2 ships the system buckets (`mandatoryExpenses`, `variableBudget`, `minReserve`) and the engines take goal-reserve / unpaid-mandatory figures as **inputs that are 0 in SP2**, so SP3 (goals) and SP4 (mortgage) register new bucket keys and wire real values without touching the engines. A schema v3 migration alters `categories` and adds two tables; features reach them only through repository interfaces exposed as Riverpod providers, exactly as SP0/SP1 established. Recalculation is triggered by the existing `ledgerRevisionProvider` bump pattern.

**Tech Stack:** Flutter (stable), Dart 3, Drift (SQLite), Riverpod (flutter_riverpod + legacy), GoRouter, intl, build_runner + drift_dev. Same stack as SP0/SP1 — no new dependencies.

## Global Constraints

- **Platform:** iOS + Android, feature parity (PRD §28.22). No web/desktop targets.
- **Storage:** Local SQLite only; no network calls anywhere (PRD §22.1, §23).
- **Money:** Integer minor units + currency code. **No floating-point money, ever.** UZS = 0 decimal digits. Same-currency arithmetic only; `Money.add`/`subtract` throw `CurrencyMismatchError` on mismatch. Percentages use **basis points** (`int`, 10000 = 100%); apply as `minor * bp ~/ 10000` (integer floor), never a `double`.
- **Buckets:** an allocation direction is identified by a `bucketKey` string. SP2 ships `mandatoryExpenses`, `variableBudget`, `minReserve`. **Undistributed** = income − Σ allocated is the implicit remainder, never a stored bucket. No engine or schema enumerates a closed set of bucket keys (SP3/SP4 add `goal:{id}` / `mortgage`).
- **Safe-limit forward inputs:** `goalReserves` and `unpaidMandatory` are engine inputs, passed **0 in SP2**. Never hardcode them inside the engine.
- **Financial "month":** Use `FinancialPeriod`, never the calendar 1st. The period start day comes from `AppSettings.periodStartDay`. The week starts on `AppSettings.weekStartIso` (1=Mon…7=Sun); use the existing `startOfWeek(date, weekStartIso)`.
- **Near-limit threshold:** `near` at **85%** of the limit (`nearThresholdBp = 8500`), `over` when spent > limit. A null limit → `noLimit`.
- **Status encoding:** safe/near/over status uses colour **+ icon + text**, never colour alone (PRD §21.8, §10.4). **Red** is reserved strictly for over-limit / error (PRD §21.2).
- **Errors:** Data/domain layers return typed `Failure`s via `Result<T>` where they can fail; user-facing text is non-technical and states a next step (PRD §26).
- **Primary-currency scope:** category limits, the variable budget, the safety buffer, and the safe limit are computed in the **primary currency** (`AppSettings.primaryCurrency`). Multi-currency safe-limit semantics track the Foundation's open question (SP5). Limit/budget amounts are stored as bare `INTEGER` minor units (no currency column); the provider layer attaches `primaryCurrency`.
- **UI language:** uz-Latn; the Foundation font already renders Cyrillic + Latin.
- **Commits:** Conventional Commits (`feat:`, `test:`, `fix:`, `chore:`, `refactor:`). Commit at the end of every task. Co-author trailer as configured.
- **Generated code:** Drift `*.g.dart` files are git-ignored; run `dart run build_runner build --delete-conflicting-outputs` after changing any `@DriftDatabase`/`Table` code, before running tests.
- **Test command:** `flutter test --concurrency=1` (default concurrency drops suites on the Windows dev box).

---

## File Structure

```
lib/
  core/
    budget/
      category_budget_engine.dart   # CategoryLimitStatus enum; categoryStatus, categoryRemaining, categoryDeviation
    allocation/
      allocation_models.dart        # AllocationMethod, AllocationDirection, AllocationTemplate, Shortfall, AllocationResult
      allocation_engine.dart        # computeAllocation(income, template) -> AllocationResult
    limit/
      safe_limit_engine.dart        # SafeLimitInputs, SafeLimit, WeeklySafeLimit; dailySafeLimit, weeklySafeLimit
  data/
    db/
      tables.dart                   # categories += kind/monthlyLimitMinor/weeklyLimitMinor; settings += variableBudgetMinor/safetyBufferMinor; +AllocationDirectionsTable, IncomeAllocationsTable
      app_database.dart             # register 2 new tables; schemaVersion -> 3
      migrations.dart               # v2->v3 onUpgrade: addColumn x5 + createTable x2 + seed default template; onCreate seeds template too
      default_allocation.dart       # the seed rows for the default allocation template
    categories/
      category_model.dart           # Category += CategoryKind kind, int? monthlyLimitMinor, int? weeklyLimitMinor
      category_repository.dart       # _map + create read the new columns (default kind=variable)
    budget/
      budget_repository.dart        # setCategoryKind, setCategoryLimits, categoryBudgetRows
    allocation/
      allocation_repository.dart    # template(), saveTemplate(), allocateIncome(), reservedTotals()
    settings/
      settings_model.dart           # AppSettings += Money variableBudget, Money safetyBuffer (defaulted)
      settings_repository.dart       # read/write the two new columns
  features/
    budgets/
      budgets_controller.dart       # category budget views + variable budget/buffer editing
      budgets_screen.dart           # Budjet tab: per-category limits + kind + status cards + variable budget/buffer
    home/
      safe_limit_cards.dart         # daily + weekly safe-limit cards
      home_screen.dart              # mount the safe-limit cards
    allocation/
      allocation_controller.dart    # compute-from-template, edit, confirm -> allocateIncome
      allocate_sheet.dart           # §8.4 confirm screen (per-direction editable)
      allocation_template_screen.dart # §8.3 reorderable template editor
      income_allocation_prompt.dart # §7.2 now / later / apply-template choice after income save
  providers/
    app_providers.dart              # +budget/allocation repo providers; +safeLimit/weeklySafeLimit/categoryBudget/allocationTemplate providers
test/
  core/budget/category_budget_engine_test.dart
  core/allocation/allocation_engine_test.dart
  core/limit/safe_limit_engine_test.dart
  data/db/schema_v3_migration_test.dart
  data/db/migration_recovery_test.dart      # MODIFY: bump failing-db fake to schemaVersion 4
  data/db/schema_v2_migration_test.dart     # MODIFY: 'schemaVersion is 2' -> 3
  data/settings/settings_repository_test.dart # MODIFY: assert new fields round-trip
  data/budget/budget_repository_test.dart
  data/allocation/allocation_repository_test.dart
  providers/safe_limit_providers_test.dart
  features/budgets/budgets_controller_test.dart
  features/home/safe_limit_cards_test.dart
  features/allocation/allocation_controller_test.dart
```

> **Note on the migration_recovery_test fake:** `test/data/db/migration_recovery_test.dart` defines `_FailingUpgradeDb` with `schemaVersion => 3` to force an upgrade past the current v2. Once the real schema becomes v3 (Task 4), that fake must become **4** or it no longer triggers `onUpgrade`. Task 4 makes this edit.

---

## Task 1: `core/budget` — category limit status engine

**Files:**
- Create: `lib/core/budget/category_budget_engine.dart`
- Test: `test/core/budget/category_budget_engine_test.dart`

**Interfaces:**
- Consumes: `Money` (`lib/core/money/money.dart`).
- Produces:
  - `enum CategoryLimitStatus { noLimit, safe, near, over }`
  - `CategoryLimitStatus categoryStatus(Money spent, Money? limit, {int nearThresholdBp = 8500})`
  - `Money categoryRemaining(Money spent, Money limit)` → `limit − spent` (signed)
  - `Money categoryDeviation(Money spent, Money limit)` → `spent − limit` (signed; §10.3 "og'ish")

- [ ] **Step 1: Write the failing test**

```dart
// test/core/budget/category_budget_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/budget/category_budget_engine.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => const Money(0, uzs).add(Money(v, uzs));

  test('null limit is noLimit regardless of spend', () {
    expect(categoryStatus(m(999999), null), CategoryLimitStatus.noLimit);
  });

  test('spent below 85% of the limit is safe', () {
    expect(categoryStatus(m(84999), m(100000)), CategoryLimitStatus.safe);
  });

  test('spent at exactly 85% is near', () {
    expect(categoryStatus(m(85000), m(100000)), CategoryLimitStatus.near);
  });

  test('spent equal to the limit is near, not over', () {
    expect(categoryStatus(m(100000), m(100000)), CategoryLimitStatus.near);
  });

  test('spent above the limit is over', () {
    expect(categoryStatus(m(100001), m(100000)), CategoryLimitStatus.over);
  });

  test('remaining and deviation are signed opposites', () {
    expect(categoryRemaining(m(30000), m(100000)), m(70000));
    expect(categoryDeviation(m(130000), m(100000)), m(30000));
    expect(categoryDeviation(m(30000), m(100000)), Money(-70000, uzs));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/core/budget/category_budget_engine_test.dart`
Expected: FAIL — `category_budget_engine.dart` does not exist / `categoryStatus` undefined.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/budget/category_budget_engine.dart
import '../money/money.dart';

/// §10.4 category budget status. `noLimit` when the category has no limit set.
enum CategoryLimitStatus { noLimit, safe, near, over }

/// Status of [spent] against an optional [limit].
///
/// `over`  when spent > limit.
/// `near`  when spent >= [nearThresholdBp] basis points of the limit (default
///         8500 = 85%).
/// `safe`  otherwise. A null limit yields `noLimit`.
///
/// Integer-only: the near test is `spent*10000 >= limit*nearThresholdBp`, so
/// no floating-point ratio is ever formed.
CategoryLimitStatus categoryStatus(Money spent, Money? limit,
    {int nearThresholdBp = 8500}) {
  if (limit == null) return CategoryLimitStatus.noLimit;
  if (spent.minorUnits > limit.minorUnits) return CategoryLimitStatus.over;
  if (spent.minorUnits * 10000 >= limit.minorUnits * nearThresholdBp) {
    return CategoryLimitStatus.near;
  }
  return CategoryLimitStatus.safe;
}

/// Signed remaining budget: `limit − spent` (positive = under budget).
Money categoryRemaining(Money spent, Money limit) => limit.subtract(spent);

/// Signed deviation: `spent − limit` (positive = over budget). §10.3.
Money categoryDeviation(Money spent, Money limit) => spent.subtract(limit);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/core/budget/category_budget_engine_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/budget/category_budget_engine.dart test/core/budget/category_budget_engine_test.dart
git commit -m "feat: add core/budget category limit status engine"
```

---

## Task 2: `core/allocation` — income allocation engine

**Files:**
- Create: `lib/core/allocation/allocation_models.dart`
- Create: `lib/core/allocation/allocation_engine.dart`
- Test: `test/core/allocation/allocation_engine_test.dart`

**Interfaces:**
- Consumes: `Money` (`lib/core/money/money.dart`).
- Produces:
  - `enum AllocationMethod { fixedAmount, percentage, remaining }`
  - `class AllocationDirection { String bucketKey; AllocationMethod method; Money? amount; int? percentBp; }`
  - `class AllocationTemplate { List<AllocationDirection> directions; }`
  - `class Shortfall { String bucketKey; Money requested; Money funded; Money get shortBy; }`
  - `class AllocationResult { Map<String,Money> perBucket; Money totalAllocated; Money undistributed; List<Shortfall> shortfalls; }`
  - `AllocationResult computeAllocation(Money income, AllocationTemplate template)`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/allocation/allocation_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/allocation/allocation_models.dart';
import 'package:financial_assistant/core/allocation/allocation_engine.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => Money(v, uzs);

  AllocationDirection fixed(String k, int v) =>
      AllocationDirection(bucketKey: k, method: AllocationMethod.fixedAmount, amount: m(v));
  AllocationDirection pct(String k, int bp) =>
      AllocationDirection(bucketKey: k, method: AllocationMethod.percentage, percentBp: bp);
  AllocationDirection rest(String k) =>
      AllocationDirection(bucketKey: k, method: AllocationMethod.remaining);

  test('fixed + percentage-of-original + remaining split an income exactly', () {
    final r = computeAllocation(m(1000000), AllocationTemplate([
      fixed('mandatoryExpenses', 400000),
      pct('minReserve', 1000), // 10% of the ORIGINAL 1,000,000 = 100,000
      rest('variableBudget'),
    ]));
    expect(r.perBucket['mandatoryExpenses'], m(400000));
    expect(r.perBucket['minReserve'], m(100000));
    expect(r.perBucket['variableBudget'], m(500000));
    expect(r.totalAllocated, m(1000000));
    expect(r.undistributed, m(0));
    expect(r.shortfalls, isEmpty);
  });

  test('with no remaining direction the leftover is undistributed', () {
    final r = computeAllocation(m(1000000), AllocationTemplate([
      fixed('mandatoryExpenses', 300000),
    ]));
    expect(r.totalAllocated, m(300000));
    expect(r.undistributed, m(700000));
  });

  test('percentage floors (no fractional minor units)', () {
    final r = computeAllocation(m(1005), AllocationTemplate([pct('minReserve', 3333)]));
    // 1005 * 3333 / 10000 = 334.9665 -> 334
    expect(r.perBucket['minReserve'], m(334));
  });

  test('§8.5 insufficient income: later fixed direction is partially funded, shortfall recorded', () {
    final r = computeAllocation(m(500000), AllocationTemplate([
      fixed('mandatoryExpenses', 400000),
      fixed('minReserve', 300000), // only 100000 left
    ]));
    expect(r.perBucket['mandatoryExpenses'], m(400000));
    expect(r.perBucket['minReserve'], m(100000));
    expect(r.totalAllocated, m(500000));
    expect(r.undistributed, m(0));
    expect(r.shortfalls.single.bucketKey, 'minReserve');
    expect(r.shortfalls.single.requested, m(300000));
    expect(r.shortfalls.single.funded, m(100000));
    expect(r.shortfalls.single.shortBy, m(200000));
  });

  test('a fully starved direction funds zero and records the shortfall', () {
    final r = computeAllocation(m(400000), AllocationTemplate([
      fixed('mandatoryExpenses', 400000),
      fixed('minReserve', 50000),
    ]));
    expect(r.perBucket.containsKey('minReserve'), isFalse);
    expect(r.shortfalls.single.bucketKey, 'minReserve');
    expect(r.shortfalls.single.funded, m(0));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/core/allocation/allocation_engine_test.dart`
Expected: FAIL — allocation files do not exist.

- [ ] **Step 3: Write the models**

```dart
// lib/core/allocation/allocation_models.dart
import '../money/money.dart';

/// How a direction claims money from an income. `goalBased` is deferred to SP3.
enum AllocationMethod { fixedAmount, percentage, remaining }

/// One line of an allocation template: send money to [bucketKey] via [method].
/// [amount] is set for `fixedAmount`; [percentBp] (basis points) for
/// `percentage`; neither for `remaining`.
class AllocationDirection {
  final String bucketKey;
  final AllocationMethod method;
  final Money? amount;
  final int? percentBp;
  const AllocationDirection({
    required this.bucketKey,
    required this.method,
    this.amount,
    this.percentBp,
  });
}

/// The single reusable template; [directions] are in priority order (§8.3).
class AllocationTemplate {
  final List<AllocationDirection> directions;
  const AllocationTemplate(this.directions);
}

/// A direction that could not be fully funded (§8.5).
class Shortfall {
  final String bucketKey;
  final Money requested;
  final Money funded;
  const Shortfall(this.bucketKey, this.requested, this.funded);
  Money get shortBy => requested.subtract(funded);
}

/// The outcome of splitting one income across the template.
class AllocationResult {
  final Map<String, Money> perBucket;
  final Money totalAllocated;
  final Money undistributed;
  final List<Shortfall> shortfalls;
  const AllocationResult({
    required this.perBucket,
    required this.totalAllocated,
    required this.undistributed,
    required this.shortfalls,
  });
}
```

- [ ] **Step 4: Write the engine**

```dart
// lib/core/allocation/allocation_engine.dart
import '../money/money.dart';
import 'allocation_models.dart';

/// Split [income] across [template] in order. `fixedAmount` takes its amount
/// (capped by what is left); `percentage` takes `percentBp` of the ORIGINAL
/// income (floored); `remaining` takes everything still unallocated. Any
/// direction that cannot be fully funded records a [Shortfall] and later
/// directions see a smaller remainder (§8.5). Whatever is left over is
/// `undistributed`.
AllocationResult computeAllocation(Money income, AllocationTemplate template) {
  final currency = income.currency;
  var remaining = income.minorUnits;
  var totalAllocated = 0;
  final perBucket = <String, Money>{};
  final shortfalls = <Shortfall>[];

  for (final d in template.directions) {
    var requested = switch (d.method) {
      AllocationMethod.fixedAmount => d.amount?.minorUnits ?? 0,
      AllocationMethod.percentage =>
        income.minorUnits * (d.percentBp ?? 0) ~/ 10000,
      AllocationMethod.remaining => remaining < 0 ? 0 : remaining,
    };
    if (requested < 0) requested = 0;

    final available = remaining < 0 ? 0 : remaining;
    final funded = requested > available ? available : requested;

    if (funded < requested) {
      shortfalls.add(Shortfall(
          d.bucketKey, Money(requested, currency), Money(funded, currency)));
    }
    if (funded > 0) {
      final existing = perBucket[d.bucketKey];
      final add = Money(funded, currency);
      perBucket[d.bucketKey] = existing == null ? add : existing.add(add);
      remaining -= funded;
      totalAllocated += funded;
    }
  }

  return AllocationResult(
    perBucket: perBucket,
    totalAllocated: Money(totalAllocated, currency),
    undistributed: Money(income.minorUnits - totalAllocated, currency),
    shortfalls: shortfalls,
  );
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/core/allocation/allocation_engine_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/core/allocation test/core/allocation
git commit -m "feat: add core/allocation income allocation engine"
```

---

## Task 3: `core/limit` — daily + weekly safe-limit engine

**Files:**
- Create: `lib/core/limit/safe_limit_engine.dart`
- Test: `test/core/limit/safe_limit_engine_test.dart`

**Interfaces:**
- Consumes: `Money`, `FinancialPeriod` (`lib/core/time/financial_period.dart`).
- Produces:
  - `class SafeLimitInputs { Money variableBudget, variableSpent, manualBuffer, totalAvailable, minReserve, goalReserves, unpaidMandatory, todaySpent; FinancialPeriod period; DateTime asOf; }`
  - `class SafeLimit { Money spendable, perDay, todaySpent, todayRemaining; int daysLeft; bool get isOver; }`
  - `class WeeklySafeLimit { Money weeklyLimit, weeklySpent, weeklyRemaining; }`
  - `SafeLimit dailySafeLimit(SafeLimitInputs i)`
  - `WeeklySafeLimit weeklySafeLimit(SafeLimit daily, {required int daysLeftInWeek, required Money weeklySpent})`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/limit/safe_limit_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/time/financial_period.dart';
import 'package:financial_assistant/core/limit/safe_limit_engine.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  Money m(int v) => Money(v, uzs);
  // Jul 1 .. Aug 1; asOf Jul 18 => 14 days remaining (Jul18..Jul31 incl. today).
  final period = FinancialPeriod.containing(DateTime(2026, 7, 18), 1);

  SafeLimitInputs inputs({
    int variableBudget = 1400000,
    int variableSpent = 0,
    int manualBuffer = 0,
    int totalAvailable = 100000000,
    int minReserve = 0,
    int goalReserves = 0,
    int unpaidMandatory = 0,
    int todaySpent = 0,
    DateTime? asOf,
  }) =>
      SafeLimitInputs(
        variableBudget: m(variableBudget),
        variableSpent: m(variableSpent),
        manualBuffer: m(manualBuffer),
        totalAvailable: m(totalAvailable),
        minReserve: m(minReserve),
        goalReserves: m(goalReserves),
        unpaidMandatory: m(unpaidMandatory),
        todaySpent: m(todaySpent),
        period: period,
        asOf: asOf ?? DateTime(2026, 7, 18),
      );

  test('daily = remaining variable budget / days left', () {
    final r = dailySafeLimit(inputs()); // 1,400,000 / 14
    expect(r.daysLeft, 14);
    expect(r.spendable, m(1400000));
    expect(r.perDay, m(100000));
    expect(r.todayRemaining, m(100000));
    expect(r.isOver, isFalse);
  });

  test('variable spent and manual buffer reduce the numerator', () {
    final r = dailySafeLimit(inputs(variableSpent: 400000, manualBuffer: 100000));
    // (1,400,000 - 400,000 - 100,000) = 900,000 / 14 = 64285 (floored)
    expect(r.spendable, m(900000));
    expect(r.perDay, m(64285));
  });

  test('free-balance cap binds when reserved money exceeds the budget', () {
    // budget says 1,400,000 but only 500,000 is free after min reserve.
    final r = dailySafeLimit(inputs(totalAvailable: 900000, minReserve: 400000));
    expect(r.spendable, m(500000));
    expect(r.perDay, m(500000 ~/ 14));
  });

  test('goalReserves and unpaidMandatory also reduce free balance (0 in SP2, real later)', () {
    final r = dailySafeLimit(inputs(
        totalAvailable: 1000000, goalReserves: 300000, unpaidMandatory: 200000));
    expect(r.spendable, m(500000)); // 1,000,000 - 300,000 - 200,000
  });

  test('never negative: over-budget yields zero spendable and negative today remaining', () {
    final r = dailySafeLimit(inputs(variableBudget: 100000, variableSpent: 300000, todaySpent: 5000));
    expect(r.spendable, m(0));
    expect(r.perDay, m(0));
    expect(r.todayRemaining, m(-5000));
    expect(r.isOver, isTrue);
  });

  test('last day of the period floors days-left at 1 (no divide by zero)', () {
    final r = dailySafeLimit(inputs(asOf: DateTime(2026, 7, 31)));
    expect(r.daysLeft, 1);
    expect(r.perDay, m(1400000));
  });

  test('today remaining subtracts what was already spent today', () {
    final r = dailySafeLimit(inputs(todaySpent: 30000));
    expect(r.perDay, m(100000));
    expect(r.todayRemaining, m(70000));
  });

  test('weekly limit derives from the daily figure', () {
    final daily = dailySafeLimit(inputs()); // perDay 100,000
    final w = weeklySafeLimit(daily, daysLeftInWeek: 3, weeklySpent: m(250000));
    expect(w.weeklyRemaining, m(300000)); // 100,000 * 3
    expect(w.weeklySpent, m(250000));
    expect(w.weeklyLimit, m(550000)); // spent + remaining
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/core/limit/safe_limit_engine_test.dart`
Expected: FAIL — `safe_limit_engine.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/limit/safe_limit_engine.dart
import '../money/money.dart';
import '../time/financial_period.dart';

/// All the figures the safe-limit computation needs (§11.2). `goalReserves`
/// and `unpaidMandatory` are 0 in SP2; SP3/SP4 supply real values without
/// changing this engine.
class SafeLimitInputs {
  final Money variableBudget;
  final Money variableSpent;
  final Money manualBuffer;
  final Money totalAvailable;
  final Money minReserve;
  final Money goalReserves;
  final Money unpaidMandatory;
  final Money todaySpent;
  final FinancialPeriod period;
  final DateTime asOf;
  const SafeLimitInputs({
    required this.variableBudget,
    required this.variableSpent,
    required this.manualBuffer,
    required this.totalAvailable,
    required this.minReserve,
    required this.goalReserves,
    required this.unpaidMandatory,
    required this.todaySpent,
    required this.period,
    required this.asOf,
  });
}

class SafeLimit {
  final Money spendable; // remaining variable budget after the free-balance cap
  final Money perDay;
  final int daysLeft;
  final Money todaySpent;
  final Money todayRemaining; // perDay − todaySpent
  const SafeLimit({
    required this.spendable,
    required this.perDay,
    required this.daysLeft,
    required this.todaySpent,
    required this.todayRemaining,
  });
  bool get isOver => todayRemaining.minorUnits < 0;
}

class WeeklySafeLimit {
  final Money weeklyLimit; // weeklySpent + weeklyRemaining
  final Money weeklySpent;
  final Money weeklyRemaining; // perDay × days left in the week
  const WeeklySafeLimit({
    required this.weeklyLimit,
    required this.weeklySpent,
    required this.weeklyRemaining,
  });
}

int _max0(int v) => v < 0 ? 0 : v;

/// §11.2 core formula:
///   remainingVariable = max(0, variableBudget − variableSpent − manualBuffer)
///   freeBalance       = totalAvailable − minReserve − goalReserves − unpaidMandatory
///   spendable         = max(0, min(remainingVariable, freeBalance))
///   perDay            = spendable ÷ daysLeft   (integer floor)
/// `daysLeft` counts whole days from the start of [asOf]'s day to the period's
/// exclusive end, floored at 1.
SafeLimit dailySafeLimit(SafeLimitInputs i) {
  final c = i.variableBudget.currency;
  final remainingVariable = _max0(i.variableBudget.minorUnits -
      i.variableSpent.minorUnits -
      i.manualBuffer.minorUnits);
  final freeBalance = i.totalAvailable.minorUnits -
      i.minReserve.minorUnits -
      i.goalReserves.minorUnits -
      i.unpaidMandatory.minorUnits;
  final cap = remainingVariable < freeBalance ? remainingVariable : freeBalance;
  final spendable = _max0(cap);

  final today = DateTime(i.asOf.year, i.asOf.month, i.asOf.day);
  final rawDays = i.period.endExclusive.difference(today).inDays;
  final daysLeft = rawDays < 1 ? 1 : rawDays;

  final perDay = spendable ~/ daysLeft;
  return SafeLimit(
    spendable: Money(spendable, c),
    perDay: Money(perDay, c),
    daysLeft: daysLeft,
    todaySpent: i.todaySpent,
    todayRemaining: Money(perDay - i.todaySpent.minorUnits, c),
  );
}

/// §11.6 weekly view, derived from the daily figure so there is one budget
/// source. `weeklyRemaining` is the per-day allowance times the days still
/// left in the current week; `weeklyLimit` adds what was already spent.
WeeklySafeLimit weeklySafeLimit(SafeLimit daily,
    {required int daysLeftInWeek, required Money weeklySpent}) {
  final c = daily.perDay.currency;
  final remaining = Money(daily.perDay.minorUnits * daysLeftInWeek, c);
  return WeeklySafeLimit(
    weeklyLimit: remaining.add(weeklySpent),
    weeklySpent: weeklySpent,
    weeklyRemaining: remaining,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --concurrency=1 test/core/limit/safe_limit_engine_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/limit test/core/limit
git commit -m "feat: add core/limit daily and weekly safe-limit engine"
```

---

## Task 4: Schema v3 — alter categories/settings, add allocation tables, migrate

**Files:**
- Modify: `lib/data/db/tables.dart`
- Modify: `lib/data/db/app_database.dart:7-19` (register tables, `schemaVersion => 3`)
- Modify: `lib/data/db/migrations.dart`
- Create: `lib/data/db/default_allocation.dart`
- Create: `test/data/db/schema_v3_migration_test.dart`
- Modify: `test/data/db/migration_recovery_test.dart:15` (fake `schemaVersion => 4`)
- Modify: `test/data/db/schema_v2_migration_test.dart:39-43` (`schemaVersion is 2` → `3`)

**Interfaces:**
- Consumes: existing `CategoriesTable`, `AppSettingsTable`, `TransactionsTable`, `_seedDefaultCategories` in `migrations.dart`.
- Produces (Drift getters after codegen): `db.allocationDirectionsTable`, `db.incomeAllocationsTable`; new columns `db.categoriesTable.kind/monthlyLimitMinor/weeklyLimitMinor`, `db.appSettingsTable.variableBudgetMinor/safetyBufferMinor`.
- Produces (Dart): `const kDefaultAllocationTemplate` (list of `(bucketKey, method, valueMinor?, percentBp?)`), `Future<void> seedDefaultAllocationTemplate(AppDatabase db)`.

- [ ] **Step 1: Write the failing migration test**

```dart
// test/data/db/schema_v3_migration_test.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';

/// A genuine v2 database: only the SP0+SP1 tables, created with the v2 shape
/// (categories WITHOUT the SP2 columns; no allocation tables). Reopening this
/// file with the real AppDatabase (v3) must run onUpgrade(2, 3).
class _V2AppDatabase extends AppDatabase {
  _V2AppDatabase(super.e);
  @override
  int get schemaVersion => 2;
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          // v2 categories shape: no kind/limit columns. Create the pre-SP2
          // tables via a raw statement so the added columns are truly absent.
          await m.database.customStatement(
            'CREATE TABLE categories (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, icon TEXT NOT NULL DEFAULT \'category\', '
            'is_default INTEGER NOT NULL DEFAULT 0, archived INTEGER NOT NULL DEFAULT 0, '
            'sort_order INTEGER NOT NULL DEFAULT 0);',
          );
          await m.createTable(appSettingsTable);
          await m.createTable(appMetaTable);
          await m.createTable(accountsTable);
          await m.createTable(transactionsTable);
          await m.createTable(recurringIncomePlansTable);
          await into(appSettingsTable)
              .insert(const AppSettingsTableCompanion(id: Value(0)));
          await into(categoriesTable).insert(
            CategoriesTableCompanion.insert(name: 'Oziq-ovqat'),
          );
        },
        beforeOpen: (d) async =>
            customStatement('PRAGMA foreign_keys = ON'),
      );
}

void main() {
  test('schemaVersion is 3', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 3);
    db.close();
  });

  test('fresh v3 open seeds the default allocation template', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dirs = await db.select(db.allocationDirectionsTable).get();
    expect(dirs, isNotEmpty);
    // income_allocations table exists and is queryable
    expect(await db.select(db.incomeAllocationsTable).get(), isEmpty);
    await db.close();
  });

  test('categories carry the SP2 columns with defaults on a fresh open', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final cats = await db.select(db.categoriesTable).get();
    expect(cats.every((c) => c.kind == 'variable'), isTrue);
    expect(cats.every((c) => c.monthlyLimitMinor == null), isTrue);
    await db.close();
  });

  test('real v2 -> v3 onUpgrade adds columns, creates tables, seeds template', () async {
    final tmp = await Directory.systemTemp.createTemp('schema_v3_upgrade');
    final dbPath = '${tmp.path}/app.db';

    final v2db = _V2AppDatabase(NativeDatabase(File(dbPath)));
    await v2db.select(v2db.appMetaTable).get(); // force onCreate
    expect(v2db.schemaVersion, 2);
    await v2db.close();

    final v3db = AppDatabase(NativeDatabase(File(dbPath)));
    // Existing category row survives and gets the default kind.
    final cats = await v3db.select(v3db.categoriesTable).get();
    expect(cats.single.name, 'Oziq-ovqat');
    expect(cats.single.kind, 'variable');
    // New tables now exist; template seeded.
    expect(await v3db.select(v3db.allocationDirectionsTable).get(), isNotEmpty);
    expect(await v3db.select(v3db.incomeAllocationsTable).get(), isEmpty);
    // Settings gained the new columns with defaults.
    final s = await v3db.select(v3db.appSettingsTable).getSingle();
    expect(s.variableBudgetMinor, 0);
    expect(s.safetyBufferMinor, 0);

    await v3db.close();
    await tmp.delete(recursive: true);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/data/db/schema_v3_migration_test.dart`
Expected: FAIL — new columns/tables/getters don't exist; `schemaVersion` is 2.

- [ ] **Step 3: Add the table columns and new tables**

In `lib/data/db/tables.dart`, add to `AppSettingsTable` (after `savingsRolloverMode`):

```dart
  IntColumn get variableBudgetMinor =>
      integer().withDefault(const Constant(0))();
  IntColumn get safetyBufferMinor =>
      integer().withDefault(const Constant(0))();
```

Add to `CategoriesTable` (after `sortOrder`):

```dart
  TextColumn get kind => text().withDefault(const Constant('variable'))();
  IntColumn get monthlyLimitMinor => integer().nullable()();
  IntColumn get weeklyLimitMinor => integer().nullable()();
```

Append two new table classes at the end of `tables.dart`:

```dart
class AllocationDirectionsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bucketKey => text()();
  TextColumn get method => text()(); // AllocationMethod.name
  IntColumn get valueMinor => integer().nullable()(); // fixedAmount
  IntColumn get percentBp => integer().nullable()(); // percentage, basis points
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class IncomeAllocationsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get incomeTransactionId =>
      integer().references(TransactionsTable, #id)();
  TextColumn get bucketKey => text()();
  IntColumn get amountMinor => integer()();
}
```

- [ ] **Step 4: Register the tables and bump the schema version**

In `lib/data/db/app_database.dart`, add the two tables to the `@DriftDatabase` list and change the version:

```dart
@DriftDatabase(tables: [
  AppSettingsTable,
  AppMetaTable,
  AccountsTable,
  CategoriesTable,
  TransactionsTable,
  RecurringIncomePlansTable,
  AllocationDirectionsTable,
  IncomeAllocationsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => buildMigration(this);
}
```

- [ ] **Step 5: Write the default-template seed**

```dart
// lib/data/db/default_allocation.dart
import 'package:drift/drift.dart';
import 'app_database.dart';

/// The default allocation template (§8.3). A neutral starter: reserve 10% of
/// each income, everything else becomes the variable spending budget. Users
/// add fixed mandatory-expense / goal / mortgage directions themselves.
/// Tuple: (bucketKey, method, valueMinor, percentBp).
const List<(String, String, int?, int?)> kDefaultAllocationTemplate = [
  ('minReserve', 'percentage', null, 1000), // 10%
  ('variableBudget', 'remaining', null, null),
];

Future<void> seedDefaultAllocationTemplate(AppDatabase db) async {
  final existing = await db.select(db.allocationDirectionsTable).get();
  if (existing.isNotEmpty) return;
  for (var i = 0; i < kDefaultAllocationTemplate.length; i++) {
    final (bucketKey, method, valueMinor, percentBp) =
        kDefaultAllocationTemplate[i];
    await db.into(db.allocationDirectionsTable).insert(
          AllocationDirectionsTableCompanion.insert(
            bucketKey: bucketKey,
            method: method,
            valueMinor: Value(valueMinor),
            percentBp: Value(percentBp),
            sortOrder: Value(i),
          ),
        );
  }
}
```

- [ ] **Step 6: Wire the migration**

In `lib/data/db/migrations.dart`: add the import, seed the template on fresh create, and add the `from < 3` upgrade branch.

Add import near the top:

```dart
import 'default_allocation.dart';
```

In `onCreate`, after `await _seedDefaultCategories(db);` add:

```dart
        await seedDefaultAllocationTemplate(db);
```

In `onUpgrade`, after the existing `if (from < 2) { ... }` block add:

```dart
        if (from < 3) {
          // v2 -> v3: category budget columns, variable budget + safety buffer
          // settings, and the two allocation tables.
          await m.addColumn(db.categoriesTable, db.categoriesTable.kind);
          await m.addColumn(
              db.categoriesTable, db.categoriesTable.monthlyLimitMinor);
          await m.addColumn(
              db.categoriesTable, db.categoriesTable.weeklyLimitMinor);
          await m.addColumn(
              db.appSettingsTable, db.appSettingsTable.variableBudgetMinor);
          await m.addColumn(
              db.appSettingsTable, db.appSettingsTable.safetyBufferMinor);
          await m.createTable(db.allocationDirectionsTable);
          await m.createTable(db.incomeAllocationsTable);
          await seedDefaultAllocationTemplate(db);
        }
```

- [ ] **Step 7: Fix the two existing migration tests for the new version**

In `test/data/db/migration_recovery_test.dart`, change the fake's version so it still forces an upgrade past the real v3:

```dart
class _FailingUpgradeDb extends AppDatabase {
  _FailingUpgradeDb(super.e);
  @override
  int get schemaVersion => 4;
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async => throw Exception('boom'),
        beforeOpen: (d) async =>
            customStatement('PRAGMA foreign_keys = ON'),
      );
}
```

In `test/data/db/schema_v2_migration_test.dart`, update the version assertion:

```dart
  test('schemaVersion is 3', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 3);
    db.close();
  });
```

- [ ] **Step 8: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes; `app_database.g.dart` now has the new columns/tables.

- [ ] **Step 9: Run the migration + recovery tests**

Run: `flutter test --concurrency=1 test/data/db/`
Expected: PASS — `schema_v3_migration_test.dart` (4 tests), `schema_v2_migration_test.dart`, `migration_recovery_test.dart`, `recovery_test.dart`, `app_database_test.dart` all green.

- [ ] **Step 10: Commit**

```bash
git add lib/data/db test/data/db
git commit -m "feat: schema v3 — category budgets, allocation tables, variable budget/buffer"
```

---

## Task 5: Settings model + repository — variable budget & safety buffer

**Files:**
- Modify: `lib/data/settings/settings_model.dart`
- Modify: `lib/data/settings/settings_repository.dart`
- Modify: `test/data/settings/settings_repository_test.dart`

**Interfaces:**
- Consumes: `db.appSettingsTable.variableBudgetMinor/safetyBufferMinor` (Task 4).
- Produces: `AppSettings.variableBudget` (`Money`, default `Money(0, primaryCurrency)` — but stored/read against `primaryCurrency`), `AppSettings.safetyBuffer` (`Money`), both threaded through `copyWith`. Read/write map the two columns.

**Design note:** the two new fields are **optional with defaults** on `AppSettings` so existing all-required constructor call sites (onboarding, recovery test, settings test) keep compiling. Their currency is always `primaryCurrency`; the repository reads them as `Money(minor, primaryCurrency)`.

- [ ] **Step 1: Add failing round-trip assertions**

In `test/data/settings/settings_repository_test.dart`, add a test (keep existing tests as-is):

```dart
  test('variable budget and safety buffer round-trip', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = DriftSettingsRepository(db);
    final base = await repo.read();
    await repo.write(base.copyWith(
      variableBudget: const Money(1400000, CurrencyRegistry.uzs),
      safetyBuffer: const Money(50000, CurrencyRegistry.uzs),
    ));
    final back = await repo.read();
    expect(back.variableBudget, const Money(1400000, CurrencyRegistry.uzs));
    expect(back.safetyBuffer, const Money(50000, CurrencyRegistry.uzs));
    await db.close();
  });
```

Ensure the file imports `Money`/`CurrencyRegistry`, `AppDatabase`, `NativeDatabase` (add any missing imports).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/data/settings/settings_repository_test.dart`
Expected: FAIL — `variableBudget`/`safetyBuffer` are not members of `AppSettings`.

- [ ] **Step 3: Add the model fields**

In `lib/data/settings/settings_model.dart`, add two fields to `AppSettings`, with defaults, and thread through `copyWith`. Add near the other fields:

```dart
  final Money variableBudget;
  final Money safetyBuffer;
```

Add to the constructor (with defaults so existing call sites compile):

```dart
    this.variableBudget = const Money(0, CurrencyRegistry.uzs),
    this.safetyBuffer = const Money(0, CurrencyRegistry.uzs),
```

Add `Money? variableBudget,` and `Money? safetyBuffer,` params to `copyWith` and the corresponding `variableBudget: variableBudget ?? this.variableBudget,` / `safetyBuffer: safetyBuffer ?? this.safetyBuffer,` lines. Add `import '../../core/money/currency.dart';` if not already imported (it is imported for `Currency`).

- [ ] **Step 4: Map the columns in the repository**

In `lib/data/settings/settings_repository.dart`, inside `read()` add to the `AppSettings(...)`:

```dart
      variableBudget: Money(row.variableBudgetMinor, CurrencyRegistry.byCode(row.primaryCurrency)),
      safetyBuffer: Money(row.safetyBufferMinor, CurrencyRegistry.byCode(row.primaryCurrency)),
```

In `write(AppSettings s)` add to the companion:

```dart
        variableBudgetMinor: Value(s.variableBudget.minorUnits),
        safetyBufferMinor: Value(s.safetyBuffer.minorUnits),
```

- [ ] **Step 5: Run the settings tests**

Run: `flutter test --concurrency=1 test/data/settings/settings_repository_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/data/settings test/data/settings
git commit -m "feat: add variable budget and safety buffer to settings"
```

---

## Task 6: Category budget fields + `BudgetRepository`

**Files:**
- Modify: `lib/data/categories/category_model.dart`
- Modify: `lib/data/categories/category_repository.dart:18-31` (`_map` + `create`)
- Create: `lib/data/budget/budget_repository.dart`
- Create: `test/data/budget/budget_repository_test.dart`

**Interfaces:**
- Consumes: `db.categoriesTable` new columns (Task 4).
- Produces:
  - `enum CategoryKind { mandatory, variable }`
  - `Category` gains `CategoryKind kind` (default `variable`), `int? monthlyLimitMinor`, `int? weeklyLimitMinor` (all defaulted so existing construction compiles).
  - `abstract class BudgetRepository { Future<void> setCategoryKind(int id, CategoryKind kind); Future<void> setCategoryLimits(int id, {int? monthlyLimitMinor, bool clearMonthly, int? weeklyLimitMinor, bool clearWeekly}); Future<List<Category>> categoriesWithBudgets({bool includeArchived}); }`
  - `class DriftBudgetRepository implements BudgetRepository`.

**Note:** limits are stored/exchanged as raw `int?` minor units (primary currency attached at the provider layer, per Global Constraints). `setCategoryLimits` uses explicit `clearMonthly`/`clearWeekly` flags to distinguish "leave unchanged" (`Value.absent`) from "set to null" (clear the limit).

- [ ] **Step 1: Write the failing test**

```dart
// test/data/budget/budget_repository_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/categories/category_model.dart';
import 'package:financial_assistant/data/budget/budget_repository.dart';

void main() {
  late AppDatabase db;
  late DriftBudgetRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBudgetRepository(db);
  });
  tearDown(() => db.close());

  test('default categories start as variable with no limits', () async {
    final cats = await repo.categoriesWithBudgets();
    expect(cats, isNotEmpty);
    expect(cats.first.kind, CategoryKind.variable);
    expect(cats.first.monthlyLimitMinor, isNull);
  });

  test('setCategoryKind flips a category to mandatory', () async {
    final id = (await repo.categoriesWithBudgets()).first.id;
    await repo.setCategoryKind(id, CategoryKind.mandatory);
    final c = (await repo.categoriesWithBudgets()).firstWhere((x) => x.id == id);
    expect(c.kind, CategoryKind.mandatory);
  });

  test('setCategoryLimits sets and clears monthly/weekly limits', () async {
    final id = (await repo.categoriesWithBudgets()).first.id;
    await repo.setCategoryLimits(id, monthlyLimitMinor: 500000, weeklyLimitMinor: 150000);
    var c = (await repo.categoriesWithBudgets()).firstWhere((x) => x.id == id);
    expect(c.monthlyLimitMinor, 500000);
    expect(c.weeklyLimitMinor, 150000);

    await repo.setCategoryLimits(id, clearMonthly: true);
    c = (await repo.categoriesWithBudgets()).firstWhere((x) => x.id == id);
    expect(c.monthlyLimitMinor, isNull);
    expect(c.weeklyLimitMinor, 150000); // unchanged
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/data/budget/budget_repository_test.dart`
Expected: FAIL — `CategoryKind`, `budget_repository.dart`, `categoriesWithBudgets` undefined.

- [ ] **Step 3: Extend the Category model**

In `lib/data/categories/category_model.dart` add the enum and fields (defaulted). The current model has `id, name, icon, isDefault, archived`. Add:

```dart
enum CategoryKind { mandatory, variable }
```

and to the `Category` class, add fields + constructor defaults:

```dart
  final CategoryKind kind;
  final int? monthlyLimitMinor;
  final int? weeklyLimitMinor;
```

Constructor gains (with defaults so existing callers compile):

```dart
    this.kind = CategoryKind.variable,
    this.monthlyLimitMinor,
    this.weeklyLimitMinor,
```

- [ ] **Step 4: Read the new columns in CategoryRepository._map**

In `lib/data/categories/category_repository.dart`, update `_map` to populate the new fields (import the model's `CategoryKind`; it's the same file so no extra import):

```dart
  Category _map(dynamic r) => Category(
        id: r.id as int,
        name: r.name as String,
        icon: r.icon as String,
        isDefault: r.isDefault as bool,
        archived: r.archived as bool,
        kind: CategoryKind.values.byName(r.kind as String),
        monthlyLimitMinor: r.monthlyLimitMinor as int?,
        weeklyLimitMinor: r.weeklyLimitMinor as int?,
      );
```

(`create` needs no change — the `kind` column defaults to `variable`.)

- [ ] **Step 5: Write the BudgetRepository**

```dart
// lib/data/budget/budget_repository.dart
import 'package:drift/drift.dart';
import '../db/app_database.dart';
import '../categories/category_model.dart';

abstract class BudgetRepository {
  Future<void> setCategoryKind(int id, CategoryKind kind);

  /// Sets or clears the monthly/weekly limit. Pass a value to set it; pass
  /// `clearMonthly`/`clearWeekly` true to null it out. Omitting both leaves
  /// that limit unchanged.
  Future<void> setCategoryLimits(
    int id, {
    int? monthlyLimitMinor,
    bool clearMonthly = false,
    int? weeklyLimitMinor,
    bool clearWeekly = false,
  });

  Future<List<Category>> categoriesWithBudgets({bool includeArchived = false});
}

class DriftBudgetRepository implements BudgetRepository {
  final AppDatabase db;
  DriftBudgetRepository(this.db);

  Category _map(dynamic r) => Category(
        id: r.id as int,
        name: r.name as String,
        icon: r.icon as String,
        isDefault: r.isDefault as bool,
        archived: r.archived as bool,
        kind: CategoryKind.values.byName(r.kind as String),
        monthlyLimitMinor: r.monthlyLimitMinor as int?,
        weeklyLimitMinor: r.weeklyLimitMinor as int?,
      );

  @override
  Future<void> setCategoryKind(int id, CategoryKind kind) async {
    await (db.update(db.categoriesTable)..where((t) => t.id.equals(id)))
        .write(CategoriesTableCompanion(kind: Value(kind.name)));
  }

  @override
  Future<void> setCategoryLimits(
    int id, {
    int? monthlyLimitMinor,
    bool clearMonthly = false,
    int? weeklyLimitMinor,
    bool clearWeekly = false,
  }) async {
    await (db.update(db.categoriesTable)..where((t) => t.id.equals(id))).write(
      CategoriesTableCompanion(
        monthlyLimitMinor: clearMonthly
            ? const Value(null)
            : (monthlyLimitMinor == null
                ? const Value.absent()
                : Value(monthlyLimitMinor)),
        weeklyLimitMinor: clearWeekly
            ? const Value(null)
            : (weeklyLimitMinor == null
                ? const Value.absent()
                : Value(weeklyLimitMinor)),
      ),
    );
  }

  @override
  Future<List<Category>> categoriesWithBudgets(
      {bool includeArchived = false}) async {
    final q = db.select(db.categoriesTable)
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    if (!includeArchived) q.where((t) => t.archived.equals(false));
    final rows = await q.get();
    return rows.map(_map).toList();
  }
}
```

- [ ] **Step 6: Run tests**

Run: `flutter test --concurrency=1 test/data/budget/budget_repository_test.dart test/data/categories/category_repository_test.dart`
Expected: PASS (both files — the category repo test still passes because the new Category fields are defaulted).

- [ ] **Step 7: Commit**

```bash
git add lib/data/categories lib/data/budget test/data/budget
git commit -m "feat: category kind + limits and BudgetRepository"
```

---

## Task 7: `AllocationRepository` — template + per-income split

**Files:**
- Create: `lib/data/allocation/allocation_repository.dart`
- Test: `test/data/allocation/allocation_repository_test.dart`

**Interfaces:**
- Consumes: `db.allocationDirectionsTable`, `db.incomeAllocationsTable`, `db.transactionsTable.allocatedMinor`; `AllocationTemplate`/`AllocationDirection`/`AllocationMethod` (`core/allocation/allocation_models.dart`); `Money`, `Currency`.
- Produces:
  - `abstract class AllocationRepository { Future<AllocationTemplate> template(); Future<void> saveTemplate(List<AllocationDirection> directions); Future<void> allocateIncome(int incomeTransactionId, Map<String,Money> perBucket); Future<Map<String,Money>> reservedTotals(Currency currency); }`
  - `class DriftAllocationRepository implements AllocationRepository`.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/allocation/allocation_repository_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/core/allocation/allocation_models.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/allocation/allocation_repository.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;
  late AppDatabase db;
  late DriftAllocationRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftAllocationRepository(db);
  });
  tearDown(() => db.close());

  Future<int> insertIncome(int minor) => db.into(db.transactionsTable).insert(
        TransactionsTableCompanion.insert(
          accountId: 1,
          type: 'income',
          amountMinor: minor,
          currencyCode: 'UZS',
          occurredAt: DateTime(2026, 7, 5),
          createdAt: DateTime(2026, 7, 5),
        ),
      );

  test('the seeded default template reads back in order', () async {
    final t = await repo.template();
    expect(t.directions.map((d) => d.bucketKey).toList(),
        ['minReserve', 'variableBudget']);
    expect(t.directions.first.method, AllocationMethod.percentage);
    expect(t.directions.first.percentBp, 1000);
    expect(t.directions.last.method, AllocationMethod.remaining);
  });

  test('saveTemplate replaces all directions and re-numbers sortOrder', () async {
    await repo.saveTemplate([
      AllocationDirection(
          bucketKey: 'mandatoryExpenses',
          method: AllocationMethod.fixedAmount,
          amount: const Money(400000, uzs)),
      AllocationDirection(
          bucketKey: 'variableBudget', method: AllocationMethod.remaining),
    ]);
    final t = await repo.template();
    expect(t.directions.map((d) => d.bucketKey).toList(),
        ['mandatoryExpenses', 'variableBudget']);
    expect(t.directions.first.amount, const Money(400000, uzs));
  });

  test('allocateIncome writes the split and updates allocatedMinor', () async {
    final incomeId = await insertIncome(1000000);
    await repo.allocateIncome(incomeId, {
      'minReserve': const Money(100000, uzs),
      'variableBudget': const Money(500000, uzs),
    });
    final row = await (db.select(db.transactionsTable)
          ..where((t) => t.id.equals(incomeId)))
        .getSingle();
    expect(row.allocatedMinor, 600000);
    final reserved = await repo.reservedTotals(uzs);
    expect(reserved['minReserve'], const Money(100000, uzs));
    expect(reserved['variableBudget'], const Money(500000, uzs));
  });

  test('re-allocating an income replaces its previous split', () async {
    final incomeId = await insertIncome(1000000);
    await repo.allocateIncome(incomeId, {'minReserve': const Money(100000, uzs)});
    await repo.allocateIncome(incomeId, {'minReserve': const Money(250000, uzs)});
    final reserved = await repo.reservedTotals(uzs);
    expect(reserved['minReserve'], const Money(250000, uzs));
    final row = await (db.select(db.transactionsTable)
          ..where((t) => t.id.equals(incomeId)))
        .getSingle();
    expect(row.allocatedMinor, 250000);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/data/allocation/allocation_repository_test.dart`
Expected: FAIL — `allocation_repository.dart` does not exist.

- [ ] **Step 3: Write the repository**

```dart
// lib/data/allocation/allocation_repository.dart
import 'package:drift/drift.dart';
import '../../core/allocation/allocation_models.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../db/app_database.dart';

abstract class AllocationRepository {
  Future<AllocationTemplate> template();
  Future<void> saveTemplate(List<AllocationDirection> directions);

  /// Replaces [incomeTransactionId]'s allocation with [perBucket] and sets the
  /// income row's `allocatedMinor` to the total, atomically.
  Future<void> allocateIncome(
      int incomeTransactionId, Map<String, Money> perBucket);

  /// Σ of every income allocation per bucketKey, as [currency].
  Future<Map<String, Money>> reservedTotals(Currency currency);
}

class DriftAllocationRepository implements AllocationRepository {
  final AppDatabase db;
  DriftAllocationRepository(this.db);

  @override
  Future<AllocationTemplate> template() async {
    final rows = await (db.select(db.allocationDirectionsTable)
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
    final dirs = rows.map((r) {
      final method = AllocationMethod.values.byName(r.method);
      return AllocationDirection(
        bucketKey: r.bucketKey,
        method: method,
        amount: r.valueMinor == null
            ? null
            : Money(r.valueMinor!, CurrencyRegistry.uzs),
        percentBp: r.percentBp,
      );
    }).toList();
    return AllocationTemplate(dirs);
  }

  @override
  Future<void> saveTemplate(List<AllocationDirection> directions) async {
    await db.transaction(() async {
      await db.delete(db.allocationDirectionsTable).go();
      for (var i = 0; i < directions.length; i++) {
        final d = directions[i];
        await db.into(db.allocationDirectionsTable).insert(
              AllocationDirectionsTableCompanion.insert(
                bucketKey: d.bucketKey,
                method: d.method.name,
                valueMinor: Value(d.amount?.minorUnits),
                percentBp: Value(d.percentBp),
                sortOrder: Value(i),
              ),
            );
      }
    });
  }

  @override
  Future<void> allocateIncome(
      int incomeTransactionId, Map<String, Money> perBucket) async {
    await db.transaction(() async {
      await (db.delete(db.incomeAllocationsTable)
            ..where((t) => t.incomeTransactionId.equals(incomeTransactionId)))
          .go();
      var total = 0;
      for (final entry in perBucket.entries) {
        if (entry.value.minorUnits == 0) continue;
        total += entry.value.minorUnits;
        await db.into(db.incomeAllocationsTable).insert(
              IncomeAllocationsTableCompanion.insert(
                incomeTransactionId: incomeTransactionId,
                bucketKey: entry.key,
                amountMinor: entry.value.minorUnits,
              ),
            );
      }
      await (db.update(db.transactionsTable)
            ..where((t) => t.id.equals(incomeTransactionId)))
          .write(TransactionsTableCompanion(allocatedMinor: Value(total)));
    });
  }

  @override
  Future<Map<String, Money>> reservedTotals(Currency currency) async {
    final rows = await db.select(db.incomeAllocationsTable).get();
    final out = <String, Money>{};
    for (final r in rows) {
      final add = Money(r.amountMinor, currency);
      final existing = out[r.bucketKey];
      out[r.bucketKey] = existing == null ? add : existing.add(add);
    }
    return out;
  }
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test --concurrency=1 test/data/allocation/allocation_repository_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/allocation test/data/allocation
git commit -m "feat: AllocationRepository — template and per-income split"
```

---

## Task 8: Providers — repos, safe limit, weekly, category status, template

**Files:**
- Modify: `lib/providers/app_providers.dart`
- Create: `test/providers/safe_limit_providers_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1–7, plus existing `databaseProvider`, `settingsProvider`, `accountRepositoryProvider`, `ledgerRepositoryProvider`, `categoryRepositoryProvider`, `ledgerRevisionProvider`, `core/ledger/summary_engine.dart` (`spentOn`, `categorySpent`, `totalsByCurrency`), `core/time/weekday.dart` (`startOfWeek`).
- Produces (new providers):
  - `budgetRepositoryProvider` (`Provider<BudgetRepository>`)
  - `allocationRepositoryProvider` (`Provider<AllocationRepository>`)
  - `allocationTemplateProvider` (`FutureProvider<AllocationTemplate>`, watches `ledgerRevisionProvider`)
  - `safeLimitProvider` (`FutureProvider<SafeLimit>`)
  - `weeklySafeLimitProvider` (`FutureProvider<WeeklySafeLimit>`)
  - `categoryBudgetsProvider` (`FutureProvider<List<CategoryBudgetView>>`)
  - `class CategoryBudgetView { Category category; Money monthSpent; Money weekSpent; CategoryLimitStatus monthStatus; CategoryLimitStatus weekStatus; }`

**Computation notes:**
- `variableSpent` (period) = Σ `categorySpent(entries, period, primary)` over categories whose `kind == variable`.
- `totalAvailable` = `totalsByCurrency(accounts, entries)[primary] ?? Money.zero(primary)`.
- `goalReserves` and `unpaidMandatory` are `Money.zero(primary)` in SP2.
- Week window: `weekStart = startOfWeek(now, weekStartIso)`, `weekEnd = weekStart + 7d`, `daysLeftInWeek = max(1, weekEnd − today in days)`, `weekSpent` = variable spent in `[weekStart, weekEnd)`.

- [ ] **Step 1: Write the failing provider test**

```dart
// test/providers/safe_limit_providers_test.dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:financial_assistant/data/settings/settings_model.dart';
import 'package:financial_assistant/data/budget/budget_repository.dart';
import 'package:financial_assistant/data/categories/category_model.dart';
import 'package:financial_assistant/providers/app_providers.dart';

void main() {
  test('safeLimitProvider computes the daily figure from ledger + budget', () async {
    final db = AppDatabase(NativeDatabase.memory());
    // One cash account, opening 100,000,000; variable budget 1,400,000.
    final accId = await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Naqd',
            type: 'cash',
            openingBalanceMinor: const Value(100000000),
          ),
        );
    final base = await DriftSettingsRepository(db).read();
    await DriftSettingsRepository(db).write(base.copyWith(
      variableBudget: const Money(1400000, CurrencyRegistry.uzs),
    ));
    // Spend 200,000 today in a variable category (category 1 is default/variable).
    await db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: accId,
            type: 'expense',
            amountMinor: -200000,
            currencyCode: 'UZS',
            categoryId: const Value(1),
            occurredAt: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        );

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final limit = await container.read(safeLimitProvider.future);
    // numerator 1,400,000 - 200,000(spent variable) = 1,200,000; today spent 200,000.
    expect(limit.spendable.minorUnits, 1200000);
    expect(limit.todaySpent, const Money(200000, CurrencyRegistry.uzs));
    await db.close();
  });

  test('categoryBudgetsProvider reports over-limit status', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final accId = await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(name: 'Naqd', type: 'cash'),
        );
    // Give category 1 a small monthly limit and overspend it.
    await DriftBudgetRepository(db)
        .setCategoryLimits(1, monthlyLimitMinor: 100000);
    await db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: accId,
            type: 'expense',
            amountMinor: -150000,
            currencyCode: 'UZS',
            categoryId: const Value(1),
            occurredAt: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        );
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final views = await container.read(categoryBudgetsProvider.future);
    final cat1 = views.firstWhere((v) => v.category.id == 1);
    expect(cat1.monthStatus, CategoryLimitStatus.over);
    await db.close();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/providers/safe_limit_providers_test.dart`
Expected: FAIL — the new providers don't exist.

- [ ] **Step 3: Add the providers**

Append to `lib/providers/app_providers.dart` (and add imports at the top):

```dart
import '../core/allocation/allocation_models.dart';
import '../core/budget/category_budget_engine.dart';
import '../core/ledger/summary_engine.dart';
import '../core/limit/safe_limit_engine.dart';
import '../core/money/money.dart';
import '../core/time/financial_period.dart';
import '../core/time/weekday.dart';
import '../data/allocation/allocation_repository.dart';
import '../data/budget/budget_repository.dart';
import '../data/categories/category_model.dart';
```

```dart
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
```

- [ ] **Step 4: Run the provider test**

Run: `flutter test --concurrency=1 test/providers/safe_limit_providers_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Run the full provider + data suites for regressions**

Run: `flutter test --concurrency=1 test/providers/ test/data/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/providers test/providers
git commit -m "feat: budget/allocation providers + safe-limit and category-status providers"
```

---

## Task 9: Budgets feature — controller + screen

**Files:**
- Create: `lib/features/budgets/budgets_controller.dart`
- Create: `lib/features/budgets/budgets_screen.dart`
- Create: `test/features/budgets/budgets_controller_test.dart`
- Modify: `lib/features/shell/routes.dart` (point the Budjet tab at `BudgetsScreen`)

**Interfaces:**
- Consumes: `categoryBudgetsProvider`, `budgetRepositoryProvider`, `settingsProvider`, `settingsRepositoryProvider`, `ledgerRevisionProvider`, `CategoryBudgetView`, `CategoryLimitStatus`, `CategoryKind`, `Money`.
- Produces:
  - `class BudgetsController { setKind(int id, CategoryKind), setMonthlyLimit(int id, Money?), setWeeklyLimit(int id, Money?), setVariableBudget(Money), setSafetyBuffer(Money) }` — each mutates via a repo then bumps `ledgerRevisionProvider`.
  - `budgetsControllerProvider` (`Provider<BudgetsController>`).
  - `BudgetsScreen` widget.
  - Helper `budgetStatusLabel(CategoryLimitStatus)` → uz-Latn text (`'xavfsiz'` / `'limitga yaqin'` / `'limitdan oshgan'` / `'limitsiz'`).

> **Shell note:** SP1 left the Budjet tab as a `PlaceholderTab`. Check `lib/features/shell/routes.dart` for the placeholder route (the tab index used by `app_shell.dart`) and swap in `const BudgetsScreen()`; keep the existing route path/label. If the tab is not yet present, add it following the pattern of the Transactions tab.

- [ ] **Step 1: Write the failing controller test**

```dart
// test/features/budgets/budgets_controller_test.dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/categories/category_model.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/budgets/budgets_controller.dart';

void main() {
  test('setMonthlyLimit persists and bumps the revision', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final before = container.read(ledgerRevisionProvider);
    await container
        .read(budgetsControllerProvider)
        .setMonthlyLimit(1, const Money(500000, CurrencyRegistry.uzs));

    expect(container.read(ledgerRevisionProvider), greaterThan(before));
    final views = await container.read(categoryBudgetsProvider.future);
    expect(views.firstWhere((v) => v.category.id == 1).category.monthlyLimitMinor,
        500000);
  });

  test('setVariableBudget updates settings', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    await container
        .read(budgetsControllerProvider)
        .setVariableBudget(const Money(1400000, CurrencyRegistry.uzs));
    final settings = await container.refresh(settingsProvider.future);
    expect(settings.variableBudget, const Money(1400000, CurrencyRegistry.uzs));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/features/budgets/budgets_controller_test.dart`
Expected: FAIL — controller does not exist.

- [ ] **Step 3: Write the controller**

```dart
// lib/features/budgets/budgets_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../data/categories/category_model.dart';
import '../../providers/app_providers.dart';

class BudgetsController {
  final Ref ref;
  BudgetsController(this.ref);

  void _bump() =>
      ref.read(ledgerRevisionProvider.notifier).update((n) => n + 1);

  Future<void> setKind(int id, CategoryKind kind) async {
    await ref.read(budgetRepositoryProvider).setCategoryKind(id, kind);
    _bump();
  }

  Future<void> setMonthlyLimit(int id, Money? limit) async {
    await ref.read(budgetRepositoryProvider).setCategoryLimits(
          id,
          monthlyLimitMinor: limit?.minorUnits,
          clearMonthly: limit == null,
        );
    _bump();
  }

  Future<void> setWeeklyLimit(int id, Money? limit) async {
    await ref.read(budgetRepositoryProvider).setCategoryLimits(
          id,
          weeklyLimitMinor: limit?.minorUnits,
          clearWeekly: limit == null,
        );
    _bump();
  }

  Future<void> _writeSettings(
      AppSettingsMutation mutate) async {
    final repo = ref.read(settingsRepositoryProvider);
    final current = await repo.read();
    await repo.write(mutate(current));
    ref.invalidate(settingsProvider);
    _bump();
  }

  Future<void> setVariableBudget(Money value) =>
      _writeSettings((s) => s.copyWith(variableBudget: value));

  Future<void> setSafetyBuffer(Money value) =>
      _writeSettings((s) => s.copyWith(safetyBuffer: value));
}

typedef AppSettingsMutation = dynamic Function(dynamic settings);

final budgetsControllerProvider =
    Provider<BudgetsController>((ref) => BudgetsController(ref));
```

> **Note:** the `dynamic` typedef avoids importing the settings model type name into this signature; if the codebase prefers strong typing, import `AppSettings` from `data/settings/settings_model.dart` and type `mutate` as `AppSettings Function(AppSettings)`. Prefer the strongly-typed version — replace `AppSettingsMutation`/`dynamic` with the real `AppSettings` type and add the import.

- [ ] **Step 4: Write the screen**

```dart
// lib/features/budgets/budgets_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/budget/category_budget_engine.dart';
import '../../core/money/money.dart';
import '../../data/categories/category_model.dart';
import '../../providers/app_providers.dart';
import 'budgets_controller.dart';

String budgetStatusLabel(CategoryLimitStatus s) => switch (s) {
      CategoryLimitStatus.noLimit => 'limitsiz',
      CategoryLimitStatus.safe => 'xavfsiz',
      CategoryLimitStatus.near => 'limitga yaqin',
      CategoryLimitStatus.over => 'limitdan oshgan',
    };

IconData budgetStatusIcon(CategoryLimitStatus s) => switch (s) {
      CategoryLimitStatus.noLimit => Icons.remove_circle_outline,
      CategoryLimitStatus.safe => Icons.check_circle_outline,
      CategoryLimitStatus.near => Icons.warning_amber_outlined,
      CategoryLimitStatus.over => Icons.error_outline,
    };

Color budgetStatusColor(CategoryLimitStatus s, ColorScheme cs) => switch (s) {
      CategoryLimitStatus.noLimit => cs.outline,
      CategoryLimitStatus.safe => cs.primary,
      CategoryLimitStatus.near => cs.tertiary,
      CategoryLimitStatus.over => cs.error, // red reserved for over/error
    };

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(categoryBudgetsProvider);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(budgetsControllerProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Budjet')),
      body: views.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Xatolik: $e')),
        data: (list) => ListView(
          children: [
            settings.maybeWhen(
              orElse: () => const SizedBox.shrink(),
              data: (s) => Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('O‘zgaruvchan budjet',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _MoneyField(
                        label: 'Oylik o‘zgaruvchan budjet',
                        value: s.variableBudget,
                        onSubmit: controller.setVariableBudget,
                      ),
                      const SizedBox(height: 8),
                      _MoneyField(
                        label: 'Xavfsizlik buferi',
                        value: s.safetyBuffer,
                        onSubmit: controller.setSafetyBuffer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ...list.map((v) => _CategoryBudgetTile(
                  view: v,
                  controller: controller,
                  color: budgetStatusColor(v.monthStatus, cs),
                )),
          ],
        ),
      ),
    );
  }
}

class _CategoryBudgetTile extends StatelessWidget {
  final CategoryBudgetView view;
  final BudgetsController controller;
  final Color color;
  const _CategoryBudgetTile(
      {required this.view, required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = view.category;
    return ListTile(
      leading: Icon(budgetStatusIcon(view.monthStatus), color: color),
      title: Text(c.name),
      subtitle: Text(
        '${budgetStatusLabel(view.monthStatus)} · '
        'sarflangan ${view.monthSpent.format()}'
        '${c.monthlyLimitMinor == null ? '' : ' / ${Money(c.monthlyLimitMinor!, view.monthSpent.currency).format()}'}',
        style: TextStyle(color: color),
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          if (c.kind == CategoryKind.mandatory)
            const Chip(label: Text('majburiy')),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editLimit(context),
          ),
        ],
      ),
    );
  }

  Future<void> _editLimit(BuildContext context) async {
    final currency = view.monthSpent.currency;
    final result = await showModalBottomSheet<Money?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LimitEditSheet(
        category: view.category,
        currency: currency,
      ),
    );
    if (result != null) {
      // A sentinel of Money(-1) means "clear"; see _LimitEditSheet.
      await controller.setMonthlyLimit(
          view.category.id, result.minorUnits < 0 ? null : result);
    }
  }
}

class _LimitEditSheet extends StatefulWidget {
  final Category category;
  final currency;
  const _LimitEditSheet({required this.category, required this.currency});
  @override
  State<_LimitEditSheet> createState() => _LimitEditSheetState();
}

class _LimitEditSheetState extends State<_LimitEditSheet> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.category.monthlyLimitMinor == null
        ? ''
        : Money(widget.category.monthlyLimitMinor!, widget.currency)
            .format(),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.category.name} — oylik limit',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Summa (bo‘sh = limitsiz)'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.pop(context, Money(-1, widget.currency)),
                  child: const Text('Limitni olib tashlash'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final m = Money.tryParse(_ctrl.text, widget.currency);
                    Navigator.pop(context, m ?? Money(-1, widget.currency));
                  },
                  child: const Text('Saqlash'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoneyField extends StatefulWidget {
  final String label;
  final Money value;
  final Future<void> Function(Money) onSubmit;
  const _MoneyField(
      {required this.label, required this.value, required this.onSubmit});
  @override
  State<_MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<_MoneyField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.value.minorUnits == 0 ? '' : widget.value.format());

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: widget.label),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.check),
          onPressed: () {
            final m = Money.tryParse(_ctrl.text, widget.value.currency);
            if (m != null) widget.onSubmit(m);
          },
        ),
      ],
    );
  }
}
```

> **Type note:** `_LimitEditSheet.currency` is declared untyped for brevity; type it as `Currency` and import `core/money/currency.dart`. The `Money(-1)` sentinel signals "clear limit" — acceptable because a real limit is never negative.

- [ ] **Step 5: Point the Budjet tab at the screen**

Open `lib/features/shell/routes.dart`, find the Budjet tab's `PlaceholderTab(...)` and replace it with `const BudgetsScreen()` (add the import). Verify against `app_shell.dart` that the tab index/label is unchanged.

- [ ] **Step 6: Run the controller test + shell smoke test**

Run: `flutter test --concurrency=1 test/features/budgets/ test/features/shell/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/budgets lib/features/shell test/features/budgets
git commit -m "feat: Budjet tab — category limits, kind, variable budget/buffer"
```

---

## Task 10: Home safe-limit cards (daily + weekly)

**Files:**
- Create: `lib/features/home/safe_limit_cards.dart`
- Modify: `lib/features/home/home_screen.dart` (mount the cards)
- Create: `test/features/home/safe_limit_cards_test.dart`

**Interfaces:**
- Consumes: `safeLimitProvider`, `weeklySafeLimitProvider`, `SafeLimit`, `WeeklySafeLimit`, `categoryBudgetsProvider` (for §11.5 "which category caused the overspend"), `Money`.
- Produces: `SafeLimitCard` and `WeeklySafeLimitCard` `ConsumerWidget`s; `overspendCategories(List<CategoryBudgetView>)` helper returning the over-limit categories' names.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/features/home/safe_limit_cards_test.dart
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/data/settings/settings_repository.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/home/safe_limit_cards.dart';

void main() {
  testWidgets('daily safe-limit card shows the per-day figure', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Naqd',
            type: 'cash',
            openingBalanceMinor: const Value(100000000),
          ),
        );
    final base = await DriftSettingsRepository(db).read();
    await DriftSettingsRepository(db)
        .write(base.copyWith(variableBudget: const Money(1400000, CurrencyRegistry.uzs)));

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: Scaffold(body: SafeLimitCard())),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bugungi xavfsiz limit'), findsOneWidget);
    await db.close();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/features/home/safe_limit_cards_test.dart`
Expected: FAIL — `safe_limit_cards.dart` does not exist.

- [ ] **Step 3: Write the cards**

```dart
// lib/features/home/safe_limit_cards.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';

class SafeLimitCard extends ConsumerWidget {
  const SafeLimitCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(safeLimitProvider);
    final budgets = ref.watch(categoryBudgetsProvider);
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: async.when(
          loading: () => const SizedBox(
              height: 48, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('Xatolik: $e'),
          data: (limit) {
            final over = limit.isOver;
            final offenders = budgets.maybeWhen(
              orElse: () => const <String>[],
              data: (list) => list
                  .where((v) => v.monthStatus.name == 'over')
                  .map((v) => v.category.name)
                  .toList(),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(over ? Icons.error_outline : Icons.savings_outlined,
                        color: over ? cs.error : cs.primary),
                    const SizedBox(width: 8),
                    Text('Bugungi xavfsiz limit',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  limit.perDay.format(),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: over ? cs.error : null),
                ),
                const SizedBox(height: 4),
                Text('Bugun qoldi: ${limit.todayRemaining.format()} '
                    '· ${limit.daysLeft} kun qoldi'),
                if (over && offenders.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Limitdan chiqqan: ${offenders.join(', ')}',
                      style: TextStyle(color: cs.error)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class WeeklySafeLimitCard extends ConsumerWidget {
  const WeeklySafeLimitCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklySafeLimitProvider);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: async.when(
          loading: () => const SizedBox(
              height: 40, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('Xatolik: $e'),
          data: (w) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Haftalik xavfsiz limit',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Limit: ${w.weeklyLimit.format()}'),
              Text('Sarflangan: ${w.weeklySpent.format()} '
                  '· Qoldi: ${w.weeklyRemaining.format()}'),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Mount the cards on Home**

In `lib/features/home/home_screen.dart`, import `safe_limit_cards.dart` and insert `const SafeLimitCard()` and `const WeeklySafeLimitCard()` into the Home card list (near the top, after the total-balance card). Match the surrounding widget-list structure (the file already lays out dashboard cards in a `ListView`/`Column`).

- [ ] **Step 5: Run the widget test + home regressions**

Run: `flutter test --concurrency=1 test/features/home/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/home test/features/home
git commit -m "feat: Home daily + weekly safe-limit cards with overspend detail"
```

---

## Task 11: Allocation confirm flow — controller, sheet, income hook

**Files:**
- Create: `lib/features/allocation/allocation_controller.dart`
- Create: `lib/features/allocation/allocate_sheet.dart`
- Create: `lib/features/allocation/income_allocation_prompt.dart`
- Modify: `lib/features/income_entry/income_entry_controller.dart` (return the new income id) and `lib/features/income_entry/income_entry_sheet.dart` (offer the §7.2 choice after save)
- Create: `test/features/allocation/allocation_controller_test.dart`

**Interfaces:**
- Consumes: `allocationTemplateProvider`, `allocationRepositoryProvider`, `computeAllocation`, `AllocationResult`, `AllocationTemplate`, `ledgerRepositoryProvider`, `ledgerRevisionProvider`, `settingsProvider`, `Money`.
- Produces:
  - `class AllocationController { Future<AllocationResult> preview(Money income); Future<void> confirm(int incomeId, Map<String,Money> perBucket); }` — `preview` runs `computeAllocation` against the current template; `confirm` calls `allocateIncome` then bumps the revision.
  - `allocationControllerProvider` (`Provider<AllocationController>`).
  - `showAllocationChoice(BuildContext, WidgetRef, {required int incomeId, required Money amount})` — the §7.2 now / later / apply-template dialog.
  - `AllocateSheet` — the §8.4 confirm screen with editable per-direction amounts.

- [ ] **Step 1: Write the failing controller test**

```dart
// test/features/allocation/allocation_controller_test.dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/core/money/currency.dart';
import 'package:financial_assistant/core/money/money.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/allocation/allocation_controller.dart';

void main() {
  const uzs = CurrencyRegistry.uzs;

  test('preview splits income by the seeded default template', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final result = await container
        .read(allocationControllerProvider)
        .preview(const Money(1000000, uzs));
    // default template: 10% minReserve, remainder variableBudget
    expect(result.perBucket['minReserve'], const Money(100000, uzs));
    expect(result.perBucket['variableBudget'], const Money(900000, uzs));
    expect(result.undistributed, const Money(0, uzs));
  });

  test('confirm writes the split and bumps the revision', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final incomeId = await db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            accountId: 1,
            type: 'income',
            amountMinor: 1000000,
            currencyCode: 'UZS',
            occurredAt: DateTime(2026, 7, 5),
            createdAt: DateTime(2026, 7, 5),
          ),
        );
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final before = container.read(ledgerRevisionProvider);
    await container.read(allocationControllerProvider).confirm(incomeId, {
      'minReserve': const Money(100000, uzs),
      'variableBudget': const Money(900000, uzs),
    });
    expect(container.read(ledgerRevisionProvider), greaterThan(before));
    final row = await (db.select(db.transactionsTable)
          ..where((t) => t.id.equals(incomeId)))
        .getSingle();
    expect(row.allocatedMinor, 1000000);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/features/allocation/allocation_controller_test.dart`
Expected: FAIL — controller does not exist.

- [ ] **Step 3: Write the controller**

```dart
// lib/features/allocation/allocation_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/allocation/allocation_engine.dart';
import '../../core/allocation/allocation_models.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';

class AllocationController {
  final Ref ref;
  AllocationController(this.ref);

  Future<AllocationResult> preview(Money income) async {
    final template = await ref.read(allocationRepositoryProvider).template();
    return computeAllocation(income, template);
  }

  Future<void> confirm(int incomeId, Map<String, Money> perBucket) async {
    await ref
        .read(allocationRepositoryProvider)
        .allocateIncome(incomeId, perBucket);
    ref.read(ledgerRevisionProvider.notifier).update((n) => n + 1);
  }
}

final allocationControllerProvider =
    Provider<AllocationController>((ref) => AllocationController(ref));
```

- [ ] **Step 4: Write the confirm sheet**

```dart
// lib/features/allocation/allocate_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/allocation/allocation_result_labels.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';
import 'allocation_controller.dart';

/// §8.4 confirm screen: shows total income, each direction's amount (editable),
/// total allocated, undistributed remainder, and free balance after. Returns
/// true when the user confirms.
class AllocateSheet extends ConsumerStatefulWidget {
  final int incomeId;
  final Money income;
  const AllocateSheet({super.key, required this.incomeId, required this.income});

  @override
  ConsumerState<AllocateSheet> createState() => _AllocateSheetState();
}

class _AllocateSheetState extends ConsumerState<AllocateSheet> {
  final Map<String, TextEditingController> _ctrls = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result =
        await ref.read(allocationControllerProvider).preview(widget.income);
    for (final e in result.perBucket.entries) {
      _ctrls[e.key] = TextEditingController(text: e.value.format());
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, Money> _current() {
    final c = widget.income.currency;
    final out = <String, Money>{};
    _ctrls.forEach((k, ctrl) {
      final m = Money.tryParse(ctrl.text, c);
      if (m != null && m.minorUnits > 0) out[k] = m;
    });
    return out;
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
          height: 160, child: Center(child: CircularProgressIndicator()));
    }
    final current = _current();
    final allocated = current.values.fold<int>(0, (s, m) => s + m.minorUnits);
    final undistributed = widget.income.minorUnits - allocated;
    final c = widget.income.currency;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Kirimni taqsimlash',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Jami kirim: ${widget.income.format()}'),
          const SizedBox(height: 12),
          ..._ctrls.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(bucketLabel(e.key))),
                    SizedBox(
                      width: 160,
                      child: TextField(
                        controller: e.value,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              )),
          const Divider(),
          Text('Taqsimlangan: ${Money(allocated, c).format()}'),
          Text('Taqsimlanmagan: ${Money(undistributed, c).format()}',
              style: TextStyle(
                  color: undistributed < 0
                      ? Theme.of(context).colorScheme.error
                      : null)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: undistributed < 0
                ? null
                : () async {
                    await ref
                        .read(allocationControllerProvider)
                        .confirm(widget.incomeId, current);
                    if (context.mounted) Navigator.pop(context, true);
                  },
            child: const Text('Tasdiqlash'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Add bucket labels + the §7.2 choice prompt**

```dart
// lib/core/allocation/allocation_result_labels.dart
/// uz-Latn display labels for the system bucket keys. Unknown keys (e.g.
/// future `goal:{id}` / `mortgage`) fall back to the raw key.
String bucketLabel(String bucketKey) => switch (bucketKey) {
      'mandatoryExpenses' => 'Majburiy xarajatlar',
      'variableBudget' => 'O‘zgaruvchan budjet',
      'minReserve' => 'Minimal zaxira',
      _ => bucketKey,
    };
```

```dart
// lib/features/allocation/income_allocation_prompt.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money/money.dart';
import '../../providers/app_providers.dart';
import 'allocate_sheet.dart';
import 'allocation_controller.dart';

/// §7.2: after an income is saved, offer allocate-now / later / apply-template.
Future<void> showAllocationChoice(
  BuildContext context,
  WidgetRef ref, {
  required int incomeId,
  required Money amount,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Hozir taqsimlash'),
            onTap: () => Navigator.pop(context, 'now'),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_check),
            title: const Text('Rejani qo‘llash'),
            subtitle: const Text('Andozadagi taqsimotni to‘g‘ridan-to‘g‘ri qo‘llash'),
            onTap: () => Navigator.pop(context, 'apply'),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Keyinroq'),
            onTap: () => Navigator.pop(context, 'later'),
          ),
        ],
      ),
    ),
  );

  if (choice == 'now' && context.mounted) {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AllocateSheet(incomeId: incomeId, income: amount),
    );
  } else if (choice == 'apply') {
    final result =
        await ref.read(allocationControllerProvider).preview(amount);
    await ref
        .read(allocationControllerProvider)
        .confirm(incomeId, result.perBucket);
  }
  // 'later' / dismissed: leave the income undistributed.
}
```

- [ ] **Step 6: Hook the income-entry flow**

In `lib/features/income_entry/income_entry_controller.dart`, ensure the save method returns the new income id (`addIncome` already returns `Future<int>`; propagate it up so the sheet has the id). In `lib/features/income_entry/income_entry_sheet.dart`, after a successful save, call `showAllocationChoice(context, ref, incomeId: id, amount: amount)` before/after closing the sheet (show it on the parent context). Match the sheet's existing `ref`/`context` usage; if the sheet is a `ConsumerStatefulWidget`, use its `ref`.

> **Deviation note:** SP1's income sheet ends with a distribute-now *stub*. This task replaces that stub call with `showAllocationChoice`. Locate the stub (a TODO or a placeholder snackbar about distribution) and swap it. If the save currently happens and the sheet pops immediately, capture the returned id first, pop, then show the choice on the parent navigator context.

- [ ] **Step 7: Run the controller test**

Run: `flutter test --concurrency=1 test/features/allocation/`
Expected: PASS (2 tests).

- [ ] **Step 8: Run income-entry regressions**

Run: `flutter test --concurrency=1 test/features/income_entry/`
Expected: PASS (update any test that asserted the old stub behaviour; income still saves and is undistributed until allocated).

- [ ] **Step 9: Commit**

```bash
git add lib/features/allocation lib/core/allocation/allocation_result_labels.dart lib/features/income_entry test/features/allocation
git commit -m "feat: income allocation flow — §7.2 choice + §8.4 confirm sheet"
```

---

## Task 12: Allocation template editor (§8.3)

**Files:**
- Create: `lib/features/allocation/allocation_template_screen.dart`
- Modify: `lib/features/budgets/budgets_screen.dart` (add an app-bar action to open the template editor)
- Create: `test/features/allocation/allocation_template_screen_test.dart`

**Interfaces:**
- Consumes: `allocationTemplateProvider`, `allocationRepositoryProvider`, `ledgerRevisionProvider`, `AllocationDirection`, `AllocationMethod`, `bucketLabel`, `Money`.
- Produces: `AllocationTemplateScreen` — a reorderable list of directions with add/edit/delete and a save that calls `saveTemplate` then bumps the revision.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/features/allocation/allocation_template_screen_test.dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_assistant/data/db/app_database.dart';
import 'package:financial_assistant/providers/app_providers.dart';
import 'package:financial_assistant/features/allocation/allocation_template_screen.dart';

void main() {
  testWidgets('template editor lists the seeded directions', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: AllocationTemplateScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Minimal zaxira'), findsOneWidget);
    expect(find.text('O‘zgaruvchan budjet'), findsOneWidget);
    await db.close();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --concurrency=1 test/features/allocation/allocation_template_screen_test.dart`
Expected: FAIL — screen does not exist.

- [ ] **Step 3: Write the template editor**

```dart
// lib/features/allocation/allocation_template_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/allocation/allocation_models.dart';
import '../../core/allocation/allocation_result_labels.dart';
import '../../providers/app_providers.dart';

class AllocationTemplateScreen extends ConsumerStatefulWidget {
  const AllocationTemplateScreen({super.key});
  @override
  ConsumerState<AllocationTemplateScreen> createState() =>
      _AllocationTemplateScreenState();
}

class _AllocationTemplateScreenState
    extends ConsumerState<AllocationTemplateScreen> {
  List<AllocationDirection>? _dirs;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allocationTemplateProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taqsimlash rejasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _dirs == null
                ? null
                : () async {
                    await ref
                        .read(allocationRepositoryProvider)
                        .saveTemplate(_dirs!);
                    ref
                        .read(ledgerRevisionProvider.notifier)
                        .update((n) => n + 1);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reja saqlandi')),
                      );
                    }
                  },
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Xatolik: $e')),
        data: (template) {
          final dirs = _dirs ??= List.of(template.directions);
          return ReorderableListView(
            onReorder: (oldI, newI) => setState(() {
              if (newI > oldI) newI -= 1;
              final item = dirs.removeAt(oldI);
              dirs.insert(newI, item);
            }),
            children: [
              for (final d in dirs)
                ListTile(
                  key: ValueKey('${d.bucketKey}-${dirs.indexOf(d)}'),
                  title: Text(bucketLabel(d.bucketKey)),
                  subtitle: Text(_methodLabel(d)),
                  trailing: const Icon(Icons.drag_handle),
                ),
            ],
          );
        },
      ),
    );
  }

  String _methodLabel(AllocationDirection d) => switch (d.method) {
        AllocationMethod.fixedAmount =>
          'Belgilangan: ${d.amount?.format() ?? '-'}',
        AllocationMethod.percentage =>
          'Foiz: ${(d.percentBp ?? 0) / 100}%',
        AllocationMethod.remaining => 'Qolgan summa',
      };
}
```

> **Scope note:** editing a direction's method/value inline (add/delete rows, change fixed amount/percent) is straightforward to extend but not required for the acceptance test; the reorder + save path is the §8.3 core. If time allows, add an edit dialog reusing `_MoneyField` from Task 9; otherwise a follow-up can add row editing. Log this as a deliberate partial in the SDD ledger.

- [ ] **Step 4: Add an entry point from Budgets**

In `lib/features/budgets/budgets_screen.dart`, add an `AppBar` action:

```dart
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Taqsimlash rejasi',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const AllocationTemplateScreen()),
            ),
          ),
        ],
```

Add the import `import '../allocation/allocation_template_screen.dart';`.

- [ ] **Step 5: Run the widget test**

Run: `flutter test --concurrency=1 test/features/allocation/allocation_template_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/allocation lib/features/budgets test/features/allocation
git commit -m "feat: allocation template editor (reorderable directions)"
```

---

## Task 13: Full-suite green + analyzer + SDD ledger roll-up

**Files:**
- Modify: `.superpowers/sdd/progress.md` (append SP2 roll-up: per-task commits, deviations, deferred items)

- [ ] **Step 1: Regenerate and run the entire suite**

Run: `dart run build_runner build --delete-conflicting-outputs`
Then: `flutter test --concurrency=1`
Expected: ALL tests pass (SP0 + SP1 + SP2). Fix any regressions (most likely: an income-entry test asserting the old distribute stub, or a Category constructor call needing the defaulted fields — both anticipated).

- [ ] **Step 2: Analyzer clean**

Run: `flutter analyze`
Expected: `No issues found!` Resolve any lint (e.g. the `dynamic` typedef in Task 9 → strongly-typed `AppSettings`; untyped `currency` field in Task 9 → `Currency`).

- [ ] **Step 3: Record the SDD roll-up**

Append an SP2 section to `.superpowers/sdd/progress.md` listing: each task's commit hash, the deliberate deviations (strongly-typed settings mutation, `Money(-1)` clear-limit sentinel, template row-editing deferred), and the deferred items (goal/mortgage buckets, `toGoal`/`askEachTime` rollover, `goalBased` method, per-period budget history).

- [ ] **Step 4: Commit**

```bash
git add .superpowers/sdd/progress.md
git commit -m "chore: SP2 SDD roll-up — allocation & safe-limit engine complete"
```

---

## Self-Review

**Spec coverage:**
- §10.3 category monthly/weekly limits, spent/remaining/deviation → Tasks 1, 6, 8, 9. ✓
- §10.4 safe/near/over status (colour+icon+text) → Task 1 (engine), Task 9 (`budgetStatusLabel`/`Icon`/`Color`). ✓
- §11.1–11.2 daily safe limit + inputs → Task 3, wired Task 8, shown Task 10. ✓
- §11.3 dynamic recalc → `ledgerRevisionProvider` watched by `safeLimitProvider`/`categoryBudgetsProvider`; bumped by every mutator (expense/income/edit/delete already bump in SP1; budget + allocation mutators bump in Tasks 9/11/12). ✓
- §11.4 underspend rollover → inherent in `remaining ÷ daysLeft` (documented); `toGoal`/`askEachTime` deferred to SP3 (Global Constraints + scope). ✓
- §11.5 overspend + offending categories → Task 10 (`isOver` + over-limit category names). ✓
- §11.6 weekly safe limit → Task 3 (`weeklySafeLimit`), Task 8 (`weeklySafeLimitProvider`), Task 10 (`WeeklySafeLimitCard`). ✓
- §8.1 buckets → generic `bucketKey` (Global Constraints); system buckets seeded Task 4. ✓
- §8.2 methods (fixed/percent/remaining) → Task 2. `goalBased` deferred. ✓
- §8.3 reorderable template → Task 12; persisted Task 7. ✓
- §8.4 confirm screen (totals, per-direction, undistributed, free balance after) → Task 11. ✓
- §8.5 insufficient income (shortfall, partial fund) → Task 2 engine; surfaced via undistributed/negative guard in Task 11. ✓
- §7.2 now/later/apply-template + undistributed on dashboard → Task 11; undistributed card already exists (SP1) and now reflects real allocations (Task 7 sets `allocatedMinor`). ✓
- Schema v3 + §20.3 recovery test → Task 4. ✓

**Placeholder scan:** No "TBD/TODO" left as deliverables. Two intentional partials are explicitly flagged and logged (template row-editing in Task 12; strong-typing cleanups in Task 13). ✓

**Type consistency:** `bucketKey` strings, `AllocationMethod`/`AllocationDirection`/`AllocationResult`, `SafeLimitInputs`/`SafeLimit`/`WeeklySafeLimit`, `CategoryLimitStatus`, `CategoryKind`, `CategoryBudgetView`, and provider names are used identically across Tasks 1–12. `setCategoryLimits` clear-flags match between repo (Task 6) and controller (Task 9). `allocateIncome(int, Map<String,Money>)` signature matches between repo (Task 7), provider consumers, and controller (Task 11). ✓
