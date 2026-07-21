# SP-B: Daily Limit From Cards — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the abstract "variable budget / safety buffer / min reserve" safe-limit formula with model A: the daily limit is the sum of balances of **Sarf-role** (spending) accounts divided by the days left in the current financial period. Rewrite the pure engine, rewire `safeLimitProvider` to sum only spending-role balances, and confirm the Home hero renders unchanged. Reserve / Kredit / Jamg'arma cards are excluded purely by role — no separate reserve, goal, or mortgage subtraction remains in the daily-limit path.

**Architecture:** The safe-limit engine (`lib/core/limit/safe_limit_engine.dart`) stays a pure, integer-only, Flutter/Drift-free module. Its inputs collapse from an eight-field `SafeLimitInputs` bag to three named parameters (`spendablePool`, `daysLeft`, `todaySpent`) plus a `hasSpendingAccounts` flag — all the reserve arithmetic (`variableBudget`, `variableSpent`, `manualBuffer`, `minReserve`, `goalReserves`, `unpaidMandatory`) is deleted because model A expresses "not spendable" as "not a Sarf card". The `SafeLimit` result type keeps its five figures and gains one field, `hasSpendingAccounts`, so SP-C/Home can tell "no Sarf cards exist" apart from "Sarf cards sum to zero"; the *meaning* of `spendable` changes (now the whole spending pool floored at zero, not a budget-vs-free-balance cap). `safeLimitProvider` filters non-archived accounts to `role == AccountRole.spending`, sums their ledger balances via the existing `totalsByCurrency` helper, computes raw days-left from the `FinancialPeriod`, and feeds the engine (`hasSpendingAccounts = spending.isNotEmpty`). Nothing downstream (`dashboardProvider`, `DashboardData.safeLimit`, `SafeLimitCard`) needs changing because the added field defaults to `true` and the five existing figures are preserved.

**Tech Stack:** Flutter (stable), Dart 3, Drift (SQLite), flutter_riverpod 3.x (+ legacy), intl. Same stack as SP0–SP5 — no new dependencies. This slice touches one engine file, one provider, and their tests; no schema or migration work (that is SP-A).

## Global Constraints

- **Platform:** Flutter/Dart; iOS + Android feature parity. No web/desktop targets.
- **Storage / ORM:** drift ORM over local SQLite; no network calls.
- **Money:** integer minor units + currency (`Money`, `lib/core/money/money.dart`). **No floating-point money, ever.** Same-currency arithmetic only; `Money.add`/`subtract` throw `CurrencyMismatchError` on mismatch. UZS = 0 decimals.
- **State:** flutter_riverpod 3.x; `StateProvider` needs `import 'package:flutter_riverpod/legacy.dart'` (already imported in `app_providers.dart`).
- **Integer division:** floor via `~/`; `daysLeft` floored at 1 (no divide-by-zero); never-negative via `_max0`. Same conventions as the current engine.
- **Test command:** `flutter test --concurrency=1` (default concurrency drops suites on the Windows dev box).
- **Commits:** Conventional Commits (`feat:`, `test:`, `refactor:`). Commit at the end of every task with trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **DEPENDS ON SP-A being merged:** `enum AccountRole { spending, reserve, credit, savings }` and the `Account.role` field must already exist in `lib/core/ledger/account.dart`, the `role` column must exist on `AccountsTable`, and `DriftAccountRepository._map` must populate `role`. Do NOT start SP-B until SP-A is merged and `flutter test --concurrency=1` is green on it.

## Design decisions for SP-B

These four open questions from the design spec are **resolved** as follows; the plan is written against them and does not leave them open:

1. **Reserve / Kredit / Jamg'arma balances are excluded by role-filtering, full stop.** There is no separate "minus reserve" subtraction anymore. `spendablePool` is the sum of `AccountRole.spending` balances only; every other role is simply never added.
2. **Mortgage `unpaidMandatory` is NOT subtracted in the daily-limit path.** That money physically lives on Kredit-role cards, which are already excluded. `MortgageRepository.unpaidMandatoryMinor(...)` stays — the mortgage module keeps it for its own payoff planning — but `safeLimitProvider` stops calling it. No double-counting: the money is excluded exactly once, by role.
3. **Goals: drop `goalReserves` from the daily-limit path.** Money earmarked for goals lives on Jamg'arma-role cards (excluded). `GoalRepository.activeReserveMinor()` is untouched and the Goals module is not modified; `safeLimitProvider` simply stops calling it.
4. **Empty state (zero Sarf accounts): the engine returns zero cleanly and flags it.** `spendablePool = Money.zero`, so `spendable = 0`, `perDay = 0`, `todayRemaining = -todaySpent`. The engine does not special-case emptiness numerically, but `SafeLimit.hasSpendingAccounts` carries whether any spending card exists (`false` here) so SP-C can distinguish "no Sarf cards exist" from "Sarf cards that happen to sum to zero" — instead of inferring it from `spendable <= 0`, which is ambiguous. **SP-C note:** Home should show a `0` figure plus a "Sarf kartasi belgilang" hint precisely when `!hasSpendingAccounts`; that display hint is SP-C's job — SP-B leaves `SafeLimitCard` as-is and only supplies the flag.

---

## Task 1 — Rewrite the pure safe-limit engine

Collapse `SafeLimitInputs` + `dailySafeLimit` into a three-parameter `dailySpendLimit`. Pure unit tests first.

**Files:**
- `test/core/limit/safe_limit_engine_test.dart` (rewrite lines 1–94 — the whole file)
- `lib/core/limit/safe_limit_engine.dart` (delete `SafeLimitInputs` L10–33 and old `dailySafeLimit` L64–95; edit `SafeLimit` doc L36; add new `dailySpendLimit`; keep `WeeklySafeLimit`/`weeklySafeLimit` L51–60, L97–109 untouched)

**Interfaces:**
- *Consumes from SP-A:* nothing directly (engine is currency-only; roles are resolved in the provider).
- *Produces:* `SafeLimit dailySpendLimit({required Money spendablePool, required int daysLeft, required Money todaySpent, bool hasSpendingAccounts = true})` — the fixed contract shared with SP-C. `SafeLimit` keeps its five figures and gains `bool hasSpendingAccounts` (defaulted `true` on the class so existing literals compile); `spendable` now means "spending pool, floored at 0".

**Steps:**

- [ ] Write the failing test. Replace the entire body of `test/core/limit/safe_limit_engine_test.dart` with tests against the new signature:

  ```dart
  // test/core/limit/safe_limit_engine_test.dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:financial_assistant/core/money/currency.dart';
  import 'package:financial_assistant/core/money/money.dart';
  import 'package:financial_assistant/core/limit/safe_limit_engine.dart';

  void main() {
    const uzs = CurrencyRegistry.uzs;
    Money m(int v) => Money(v, uzs);

    test('daily = spendable pool / days left (integer floor)', () {
      final r = dailySpendLimit(
          spendablePool: m(1400000), daysLeft: 14, todaySpent: m(0));
      expect(r.daysLeft, 14);
      expect(r.spendable, m(1400000));
      expect(r.perDay, m(100000)); // 1,400,000 / 14
      expect(r.todayRemaining, m(100000));
      expect(r.isOver, isFalse);
    });

    test('floors the per-day figure', () {
      final r = dailySpendLimit(
          spendablePool: m(900000), daysLeft: 14, todaySpent: m(0));
      expect(r.perDay, m(64285)); // 900,000 / 14 = 64285.7 -> 64285
    });

    test('empty pool yields zero limit (zero Sarf accounts)', () {
      final r =
          dailySpendLimit(spendablePool: m(0), daysLeft: 14, todaySpent: m(0));
      expect(r.spendable, m(0));
      expect(r.perDay, m(0));
      expect(r.todayRemaining, m(0));
    });

    test('negative pool is floored at zero, never negative spendable', () {
      final r = dailySpendLimit(
          spendablePool: m(-500000), daysLeft: 10, todaySpent: m(5000));
      expect(r.spendable, m(0));
      expect(r.perDay, m(0));
      expect(r.todayRemaining, m(-5000));
      expect(r.isOver, isTrue);
    });

    test('days-left floored at 1 (no divide by zero on the last day)', () {
      final r = dailySpendLimit(
          spendablePool: m(1400000), daysLeft: 0, todaySpent: m(0));
      expect(r.daysLeft, 1);
      expect(r.perDay, m(1400000));
    });

    test('today remaining subtracts what was already spent today', () {
      final r = dailySpendLimit(
          spendablePool: m(1400000), daysLeft: 14, todaySpent: m(30000));
      expect(r.perDay, m(100000));
      expect(r.todayRemaining, m(70000));
    });

    test('hasSpendingAccounts flag propagates from the caller', () {
      final withCard = dailySpendLimit(
          spendablePool: m(0),
          daysLeft: 14,
          todaySpent: m(0),
          hasSpendingAccounts: true);
      expect(withCard.hasSpendingAccounts, isTrue);
      expect(withCard.spendable, m(0)); // present-but-empty pool
      final none = dailySpendLimit(
          spendablePool: m(0),
          daysLeft: 14,
          todaySpent: m(0),
          hasSpendingAccounts: false);
      expect(none.hasSpendingAccounts, isFalse);
    });

    test('hasSpendingAccounts defaults to true when omitted', () {
      final r = dailySpendLimit(
          spendablePool: m(1400000), daysLeft: 14, todaySpent: m(0));
      expect(r.hasSpendingAccounts, isTrue);
    });

    test('weekly limit still derives from the daily figure', () {
      final daily = dailySpendLimit(
          spendablePool: m(1400000), daysLeft: 14, todaySpent: m(0));
      final w = weeklySafeLimit(daily, daysLeftInWeek: 3, weeklySpent: m(250000));
      expect(w.weeklyRemaining, m(300000)); // 100,000 * 3
      expect(w.weeklySpent, m(250000));
      expect(w.weeklyLimit, m(550000));
    });
  }
  ```

- [ ] Run — expect FAIL (compile error: `dailySpendLimit` undefined, `SafeLimitInputs` still referenced nowhere):

  ```
  flutter test --concurrency=1 test/core/limit/safe_limit_engine_test.dart
  ```

- [ ] Minimal impl. In `lib/core/limit/safe_limit_engine.dart`: delete the `SafeLimitInputs` class (L10–33) and the old `dailySafeLimit` function (L64–95, including its `//§11.2` doc comment). Remove the now-unused `import '../time/financial_period.dart';` from L2 (the engine no longer takes a period — the provider computes `daysLeft`). Update the `SafeLimit.spendable` field comment (L36). Add the new function. Result (top of file + new function):

  ```dart
  import '../money/money.dart';

  class SafeLimit {
    final Money spendable; // the spending pool, floored at zero
    final Money perDay;
    final int daysLeft;
    final Money todaySpent;
    final Money todayRemaining; // perDay − todaySpent
    // Whether at least one non-archived Sarf-role card exists. Lets Home/SP-C
    // tell "no spending cards" (show "Sarf kartasi belgilang") apart from
    // "spending cards summing to zero" — never inferred from spendable <= 0.
    // Defaulted true so existing value-widget SafeLimit literals stay valid.
    final bool hasSpendingAccounts;
    const SafeLimit({
      required this.spendable,
      required this.perDay,
      required this.daysLeft,
      required this.todaySpent,
      required this.todayRemaining,
      this.hasSpendingAccounts = true,
    });
    bool get isOver => todayRemaining.minorUnits < 0;
  }
  ```

  ```dart
  int _max0(int v) => v < 0 ? 0 : v;

  /// Model-A daily spend limit: the whole spendable pool — the summed balance
  /// of the Sarf-role (spending) cards — split evenly across the days left in
  /// the current financial period.
  ///
  ///   spendable = max(0, spendablePool)
  ///   perDay    = spendable ÷ daysLeft        (integer floor)
  ///
  /// [daysLeft] is floored at 1 so the last day of a period never divides by
  /// zero. [todaySpent] only drives the "today remaining" figure; it does not
  /// reduce the pool. Reserve / Kredit / Jamg'arma balances are already
  /// excluded upstream by role, so there is no reserve subtraction here.
  /// [hasSpendingAccounts] is passed straight through to the result so callers
  /// can show an "add a spending card" empty state without inspecting figures.
  SafeLimit dailySpendLimit({
    required Money spendablePool,
    required int daysLeft,
    required Money todaySpent,
    bool hasSpendingAccounts = true,
  }) {
    final c = spendablePool.currency;
    final days = daysLeft < 1 ? 1 : daysLeft;
    final spendable = _max0(spendablePool.minorUnits);
    final perDay = spendable ~/ days;
    return SafeLimit(
      spendable: Money(spendable, c),
      perDay: Money(perDay, c),
      daysLeft: days,
      todaySpent: todaySpent,
      todayRemaining: Money(perDay - todaySpent.minorUnits, c),
      hasSpendingAccounts: hasSpendingAccounts,
    );
  }
  ```

  Leave `WeeklySafeLimit` (L51–60) and `weeklySafeLimit` (L97–109) exactly as they are — `weeklySafeLimit` still takes a `SafeLimit` and is unaffected by this slice.

- [ ] Run — expect PASS:

  ```
  flutter test --concurrency=1 test/core/limit/safe_limit_engine_test.dart
  ```

- [ ] Commit: `refactor(limit): daily spend limit from spending pool, drop reserve inputs`.

---

## Task 2 — Rewire `safeLimitProvider` to sum Sarf-role balances

Sum only `AccountRole.spending` balances, compute days-left from the period, feed the new engine. Drop the budget/goal/mortgage reads from this provider.

**Files:**
- `test/providers/safe_limit_providers_test.dart` (rewrite the two safe-limit tests L16–98; keep the `categoryBudgetsProvider` test L100–128 unchanged)
- `lib/providers/app_providers.dart` (rewrite `safeLimitProvider` L363–414; add `import '../core/ledger/account.dart';` near L1–31)

**Interfaces:**
- *Consumes from SP-A:* `AccountRole.spending` and `Account.role` — read via `accountRepositoryProvider.list(includeArchived: false)`, which SP-A's `DriftAccountRepository._map` already populates from the `role` column.
- *Produces:* `safeLimitProvider` → `Future<SafeLimit>` with `spendable == Σ balance(spending accounts in primary currency)` floored at 0, `daysLeft` from `FinancialPeriod.containing(now, periodStartDay)`, `todaySpent` from `spentOn(now, entries, currency)`, and `hasSpendingAccounts == spending.isNotEmpty`.

**Steps:**

- [ ] Write the failing tests. Replace the two safe-limit tests (L16–98) in `test/providers/safe_limit_providers_test.dart`. These insert accounts with explicit `role` values (cash defaults to `spending` under SP-A's migration, but tests set it explicitly to pin behaviour) and assert role-filtered summation. Note the imports at the top of the file already include `Money`, `currency`, `app_providers`, and drift helpers; add nothing new.

  ```dart
  test('safeLimitProvider sums only Sarf-role account balances', () async {
    final db = AppDatabase(NativeDatabase.memory());
    // Spending card: 8,000,000. Reserve card: 5,000,000 (must be excluded).
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Asosiy',
            type: 'bankCard',
            openingBalanceMinor: const Value(8000000),
            role: const Value('spending'),
          ),
        );
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Zaxira',
            type: 'bankCard',
            openingBalanceMinor: const Value(5000000),
            role: const Value('reserve'),
          ),
        );

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final limit = await container.read(safeLimitProvider.future);
    // Only the 8,000,000 Sarf balance is in the pool; reserve is excluded.
    expect(limit.spendable.minorUnits, 8000000);
    // perDay = pool / daysLeft; daysLeft depends on the period, so assert the
    // invariant rather than a hard-coded quotient.
    expect(limit.perDay.minorUnits, 8000000 ~/ limit.daysLeft);
    expect(limit.hasSpendingAccounts, isTrue);
    await db.close();
  });

  test('safeLimitProvider flags a present-but-empty spending pool', () async {
    // A Sarf card exists but its balance nets to zero: hasSpendingAccounts is
    // still true, so SP-C must NOT show the "add a spending card" hint here.
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Asosiy',
            type: 'bankCard',
            openingBalanceMinor: const Value(0),
            role: const Value('spending'),
          ),
        );

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final limit = await container.read(safeLimitProvider.future);
    expect(limit.spendable.minorUnits, 0);
    expect(limit.perDay.minorUnits, 0);
    expect(limit.hasSpendingAccounts, isTrue);
    await db.close();
  });

  test('safeLimitProvider is zero and unflagged with no Sarf accounts',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Jamgarma',
            type: 'savings',
            openingBalanceMinor: const Value(3000000),
            role: const Value('savings'),
          ),
        );

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final limit = await container.read(safeLimitProvider.future);
    expect(limit.spendable.minorUnits, 0);
    expect(limit.perDay.minorUnits, 0);
    expect(limit.hasSpendingAccounts, isFalse);
    await db.close();
  });
  ```

  Also update the surviving import list: the tests no longer need `GoalRepository`/`GoalDraft`/`ContributionSource` (`data/goals/*`) or the `variableBudget` settings writes — remove those imports **only if** the `categoryBudgetsProvider` test (kept) does not use them. It does not, so drop `import '.../data/goals/goal_model.dart';` and `import '.../data/goals/goal_repository.dart';` and the `Money`/settings churn that only the deleted goal-earmark test used. Keep `budget_repository`, `category_budget_engine`, `currency`, `money`, `settings_repository`, `app_database`, and `app_providers` imports (the retained test needs them).

- [ ] Run — expect FAIL (the old provider still references `settings.variableBudget`, `SafeLimitInputs`, `goalReserves`, etc., which Task 1 deleted — so this file will not even compile until the provider is rewritten; the assertions on role-filtered sums are the behavioural target):

  ```
  flutter test --concurrency=1 test/providers/safe_limit_providers_test.dart
  ```

- [ ] Minimal impl. In `lib/providers/app_providers.dart` add `import '../core/ledger/account.dart';` to the import block (near the other `../core/ledger/*` imports around L5–6). Replace `safeLimitProvider` (L363–414) with:

  ```dart
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
  ```

  This deletes the provider's reads of `budgetRepositoryProvider.categoriesWithBudgets(...)`, `categorySpent(...)` for variable spend, `goalRepositoryProvider.activeReserveMinor()`, and `mortgageRepositoryProvider.unpaidMandatoryMinor(...)` **within this provider only**. Those repository methods and their providers stay — `categoryBudgetsProvider`, the Goals module, and the Mortgage module still use them. Do NOT touch `settings_model.dart` fields (`variableBudget`/`safetyBuffer`/`minReserve`) in this slice — retiring the settings fields, their editors, and onboarding steps is SP-C's job; leaving them present-but-unread keeps SP-B's blast radius to the engine + this provider.

- [ ] Run — expect PASS (both provider files compile and the role-filtered sums assert correctly):

  ```
  flutter test --concurrency=1 test/providers/safe_limit_providers_test.dart
  ```

- [ ] Commit: `feat(limit): daily safe limit from Sarf-role card balances`.

---

## Task 3 — Confirm Home display wiring (widget test)

`SafeLimit`'s shape is unchanged, so `dashboardProvider`, `DashboardData.safeLimit`, and `SafeLimitCard` need no code change. This task proves that with the existing widget test, updating only the fixture so the account carries a spending role and dropping the now-meaningless `variableBudget` write.

**Files:**
- `test/features/home/safe_limit_cards_test.dart` (edit the first test L15–49; the three pure-value-widget tests L51–123 use a hand-built `const SafeLimit(...)` literal and need no change — the new `hasSpendingAccounts` field defaults to `true`, so those literals stay valid without edits)
- No `lib/` changes expected. If `flutter analyze` flags an unused import in `dashboard_data.dart` or `home_screen.dart`, that is a signal something was over-deleted — revert, do not chase it.

**Interfaces:**
- *Consumes from SP-A:* `role` column on `AccountsTable` (fixture sets `role: const Value('spending')`).
- *Produces:* proof that the provider-derived `SafeLimit` still renders `todayRemaining` as the hero figure and `perDay` in the "Kunlik limit" supporting line.

**Steps:**

- [ ] Update the first widget test (L15–49). The account must be a Sarf card and the obsolete `variableBudget` settings write is removed; the rest of the test (reading the limit through the provider, feeding it to `SafeLimitCard`, asserting `BUGUN QOLDI`, the `todayRemaining` headline, and `Kunlik limit`) is unchanged:

  ```dart
  testWidgets('daily safe-limit card shows the per-day figure', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.accountsTable).insert(
          AccountsTableCompanion.insert(
            name: 'Naqd',
            type: 'cash',
            openingBalanceMinor: const Value(100000000),
            role: const Value('spending'),
          ),
        );

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final limit = await container.read(safeLimitProvider.future);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SafeLimitCard(limit: limit))),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('BUGUN QOLDI'), findsOneWidget);
    expect(find.text(limit.todayRemaining.format()), findsOneWidget);
    expect(find.textContaining('Kunlik limit'), findsOneWidget);
    await db.close();
  });
  ```

  Remove the now-unused `DriftSettingsRepository` import and its two `base`/`write` lines from this test if no other test in the file uses them (the other three build `SafeLimit` literals, so they do not). Keep `settings_repository` import only if still referenced.

- [ ] Run — expect PASS:

  ```
  flutter test --concurrency=1 test/features/home/safe_limit_cards_test.dart
  ```

- [ ] Full-suite regression (goldens for `SafeLimitCard` feed hand-built `SafeLimit` literals, so they should not shift; if any Home golden moves, inspect the diff — a shift means a wiring regression, not an expected update):

  ```
  flutter test --concurrency=1
  ```

- [ ] Commit: `test(home): safe-limit widget fixture uses a Sarf-role account`.

---

## Notes on dead code (be conservative)

- **Deleted by this slice:** `SafeLimitInputs` class and the old `dailySafeLimit` function (`safe_limit_engine.dart`); the `import '../time/financial_period.dart';` in that engine file; the provider's variable-spend / goal-reserve / unpaid-mandatory reads inside `safeLimitProvider`.
- **Kept (NOT dead here):** `WeeklySafeLimit` + `weeklySafeLimit` (only its own unit test uses it, but it is valid against the unchanged `SafeLimit` and out of this slice's scope). `GoalRepository.activeReserveMinor()`, `MortgageRepository.unpaidMandatoryMinor(...)`, `categoryBudgetsProvider`, `budgetRepositoryProvider` — all still used by their own modules. `AppSettings.variableBudget` / `safetyBuffer` / `minReserve` and their editors/onboarding — **leave for SP-C** to retire.
