# Allocation & Safe-Limit Engine — Design Spec

**Sub-project:** 2 of 7 (Allocation & safe-limit engine)
**Parent product:** Shaxsiy Moliyaviy Assistent (Personal Financial Assistant) — Flutter MVP
**Depends on:** Sub-project 0 (Foundation) + Sub-project 1 (Accounts & transactions) — both merged to `master`
**Date:** 2026-07-18
**Status:** Approved for planning

---

## 1. Context

Third of seven sequential sub-projects. Builds on the Foundation's pure core
(`Money`, `Currency`, `FinancialPeriod`, `Result`) and SP1's derived
double-entry ledger + `core/ledger` engine, repository/provider pattern, and the
5-tab shell with real Home cards.

SP2 delivers the three pieces SP1 explicitly deferred so that all "limit" and
"allocation" math lands in one place:

- **§10.3–§10.4** — category budgets: monthly + weekly limits, spent / remaining
  / deviation, and safe / near-limit / over-limit status (shown by colour **and**
  text **and** icon, per §10.4).
- **§11** — the daily **and** weekly safe-limit engine with dynamic recalculation
  (§11.1–§11.6).
- **§8 / §7.2** — income allocation across directions ("buckets") via a single
  reusable template, the §8.4 confirm screen, and §8.5 insufficient-income
  handling.

### Product constraints carried from Foundation / SP1 / PRD
- Flutter, iOS + Android, feature parity (§28.22). Local SQLite only, offline.
- Primary currency UZS; each account may carry its own currency; **no FX** (§27).
- Correctness of the math is the product: pure calculation logic is separated
  from data and UI and unit-tested in isolation (build-approach memory).
- Recalculation after every relevant operation; reports over 10k transactions
  < 2s (§24). The safe limit recomputes after every expense (§28.7).

### Forward-reference resolution (the central scope decision)
§8's allocation directions and §11's safe-limit inputs both reference **goals**
(SP3) and **mortgage** (SP4), which do not exist yet. SP2 resolves this with a
**generic allocation-bucket model**: buckets are identified by a string key, SP2
ships only the system buckets that exist now, and goals/mortgage register their
own bucket keys in their own sub-projects. The pure engines take goal-reserve and
mandatory-payment figures as **inputs that are 0 in SP2**, so SP3/SP4 wire real
values in without touching the engines or their tests.

## 2. Architecture: derived buckets + three pure engines

Continues SP1's principle — everything is **derived**, nothing denormalized.
Three pure Dart engines (no Flutter, no Drift) own all the math; repositories
load domain data and the engines define the meaning of every derived number.

- **`core/allocation`** — splits an income across buckets from the template.
- **`core/limit`** — the daily/weekly safe-limit computation.
- **`core/budget`** — per-category limit status.

### 2.1 Buckets
A **bucket** is an allocation direction identified by a `bucketKey` string.

- System buckets shipped in SP2: `mandatoryExpenses`, `variableBudget`,
  `minReserve`. **Undistributed** is the implicit remainder (income −
  Σ allocated), never a stored bucket — consistent with SP1's `undistributed()`.
- Future SPs register `goal:{id}` (SP3) and `mortgage` (SP4) keys. Nothing in the
  SP2 schema or engines enumerates a closed set of buckets, so no migration or
  engine change is needed to add them.

## 3. Pure core

Pure Dart, exhaustively unit-tested on fixture lists — no DB, no widgets — exactly
like `Money` / `FinancialPeriod` / `core/ledger`.

### 3.1 `core/limit` — the safe-limit engine (the heart, §11.2)

Inputs (a `SafeLimitInputs` value object):
- `variableBudget: Money` — the period's variable-expense budget (§4 below).
- `variableSpent: Money` — Σ expenses in **variable**-flagged categories in the
  period.
- `manualBuffer: Money` — the user's manual safety buffer (§11.2), a setting.
- `totalAvailable: Money` — free balance from the ledger (the account currency in
  scope; primary-currency accounts in MVP).
- `minReserve: Money` — the minimal reserve (existing setting).
- `goalReserves: Money` — **0 in SP2**; SP3 supplies real values.
- `unpaidMandatory: Money` — **0 in SP2**; SP4/mandatory-payment tracking supplies
  real values.
- `period: FinancialPeriod`, `asOf: DateTime`.

Core computation, returned as a `SafeLimit` result value:
```
remainingVariable = max(0, variableBudget − variableSpent − manualBuffer)
freeBalance       = totalAvailable − minReserve − goalReserves − unpaidMandatory
spendable         = min(remainingVariable, max(0, freeBalance))
daysLeft          = max(1, whole days from asOf's date to period.endExclusive)
daily             = spendable ÷ daysLeft          // integer minor units, floored
```
- Flooring integer division keeps the limit conservative (never suggests more than
  is safe). `daysLeft` floored at 1 avoids divide-by-zero on the period's last day.
- The `freeBalance` cap ensures the app never labels reserved money as "safe to
  spend," even if the variable budget was set higher than the cash on hand.
- The result also exposes `todaySpent`, `todayRemaining = daily − todaySpent`, and
  an over/under flag (§11.5): when `todayRemaining < 0`, the overspend amount is
  surfaced; the offending categories come from the budget engine (§3.3).

**Underspend rollover (§11.4).** Because `daily = remaining ÷ daysLeft` is
recomputed live, unspent money from earlier days is inherently spread across the
remaining days (`rolloverDays`, the settings default). The `toGoal` and
`askEachTime` modes move saved money into a goal and are **inert until SP3** (no
goal buckets exist yet); the setting is honoured as `rolloverDays` in SP2.

**Weekly safe limit (§11.6).** Derived from the same engine, not a second budget:
the weekly view computes the daily figure, then reports `weeklyLimit = daily ×
daysLeftInCurrentWeekWithinPeriod`, `weeklySpent` (variable spent this week), and
`weeklyRemaining`. `weekStartIso` (existing setting) defines the week.

### 3.2 `core/allocation` — the allocation engine (§8)

Types:
- `AllocationMethod { fixedAmount, percentage, remaining }` (`goalBased` deferred
  to SP3).
- `AllocationDirection { bucketKey, AllocationMethod method, Money? amount,
  int? percentBp }` — `amount` for fixed, `percentBp` (basis points) for
  percentage, neither for remaining.
- `AllocationTemplate { List<AllocationDirection> ordered }` — the single reusable
  template; order is the §8.3 priority order the user can rearrange.

Function `computeAllocation(Money income, AllocationTemplate template)` →
`AllocationResult`:
- Walk directions in order. `fixedAmount` takes its amount (capped by remaining);
  `percentage` takes `percentBp` of the **original income**; `remaining` takes all
  that is left.
- `AllocationResult { Map<String,Money> perBucket, Money totalAllocated, Money
  undistributed, List<Shortfall> shortfalls }`.
- **§8.5 insufficient income.** When the running remainder cannot satisfy a
  direction, it is funded partially and a `Shortfall { bucketKey, requested,
  funded }` is recorded; later directions get nothing. `undistributed = income −
  totalAllocated` (≥ 0). This drives §8.4's "which directions are underfunded" and
  "amount short" display. (Explicit per-direction priority tiers beyond template
  order are deferred; template order *is* the priority.)

The result feeds the §8.4 confirm screen (total income, per-direction amount, total
allocated, undistributed remainder, free balance after) where each amount is
editable before confirming.

### 3.3 `core/budget` — category limit status (§10.4)

- `CategoryLimitStatus { safe, near, over }`.
- `categoryStatus(Money spent, Money? limit, {int nearThresholdBp = 8500})` →
  `over` when `spent > limit`, `near` when `spent ≥ 85% of limit`, else `safe`;
  a null limit yields a distinct `noLimit`/`safe` (rendered as "no limit").
- `categoryDeviation(spent, limit)` → signed `Money` (spent − limit) for §10.3's
  "limitdan og'ish".
- Applies to both the monthly and the weekly limit by passing the matching
  spent/limit pair over the matching period.

**Near-limit threshold = 85%** of the budget (the PRD leaves the cutoff
unspecified; this is the chosen default, overridable if it proves wrong in QA).

## 4. Where the variable budget comes from

Per the brainstorming decision (standalone budget + category flag):

- The **period variable budget is one standalone `Money` value** the user sets
  directly in the Budgets screen. It is the numerator source for §3.1.
- Each **category carries a `kind` flag** (`mandatory` | `variable`). "Variable
  spent" = Σ expenses in variable categories within the period. Category budgets
  (§10.3) are **separate** per-category tripwires and do **not** sum into the
  variable budget (decoupled — simplest engine, one source of truth per concern).
- Income allocation to the `variableBudget` bucket, on confirm, **offers to set /
  update** the current period's variable budget to that amount — the same stored
  value, so allocation and the daily limit stay consistent without coupling the
  category budgets in.
- Stored per current financial period; a new period starts from the previous
  period's value (a sensible default the user can change). Within a period,
  underspend rolls forward via the daily formula; across periods it resets.

## 5. Data model (schema v3)

SP2 introduces **schema v3** over SP1's v2. `onUpgrade` uses `createTable` for new
tables and `ALTER TABLE ... ADD COLUMN` for the category additions (the
`drift_dev schema` CLI is not required for either, per SP1's note). Bump
`AppDatabase.schemaVersion` to 3 and register new tables in `@DriftDatabase`. The
Foundation snapshot-before-upgrade recovery runs automatically.

### 5.1 `categories` (altered)
| col | type | notes |
|---|---|---|
| kind | TEXT default `variable` | `mandatory` / `variable` (§8.1 split) |
| monthlyLimitMinor | INTEGER null | null = no monthly limit (§10.3) |
| weeklyLimitMinor | INTEGER null | null = no weekly limit (§10.3) |

### 5.2 `allocation_directions` (the single template)
| col | type | notes |
|---|---|---|
| id | INTEGER PK | |
| bucketKey | TEXT | `mandatoryExpenses` / `variableBudget` / `minReserve` / future keys |
| method | TEXT | `fixedAmount` / `percentage` / `remaining` |
| valueMinor | INTEGER null | for `fixedAmount` |
| percentBp | INTEGER null | basis points, for `percentage` |
| sortOrder | INTEGER | the §8.3 priority order (user-reorderable) |

### 5.3 `income_allocations` (actual per-income split)
| col | type | notes |
|---|---|---|
| id | INTEGER PK | |
| incomeTransactionId | INTEGER FK→transactions | the income row |
| bucketKey | TEXT | |
| amountMinor | INTEGER | Σ per bucketKey = that bucket's reserved total |

`Σ amountMinor` for an income = that row's `allocatedMinor` (SP1 column reused);
`undistributed()` (SP1) becomes meaningful. Index on `incomeTransactionId` and
`bucketKey`.

### 5.4 Settings (added)
`variableBudgetMinor` (current-period variable budget), `safetyBufferMinor`
(§11.2 manual buffer). `minReserve`, `dailyLimitMethod`, `savingsRolloverMode`,
`periodStartDay`, `weekStartIso` already exist from the Foundation.

### 5.5 Migration v2 → v3
Real `onUpgrade` step: `ALTER TABLE categories` (three columns with defaults),
`createTable` for `allocation_directions` + `income_allocations`, seed the default
allocation template rows. **v2→v3 success test and a forced-failure recovery test
(§20.3) both land here**, alongside the existing v1→v2 tests.

## 6. Data layer (`data/`)

Follows the SP1 pattern: repository interface + Drift-backed impl in small focused
files, exposed via Riverpod providers; features never touch Drift directly. All
repositories return `Result<T, Failure>`; failures map to non-technical, next-step
messages (§26).

- **`BudgetRepository`** — get/set per-category monthly & weekly limits and the
  category `kind` flag; get/set the period variable budget and safety buffer.
- **`AllocationRepository`** — template read + reorder + edit; write an income's
  allocation split (in one Drift transaction) and update the income's
  `allocatedMinor`; read per-income and per-bucket reserved totals.

Reads that the engines need (variable spent, category spent, free balance) reuse
SP1's `LedgerRepository` + `core/ledger`.

## 7. Features & UI (`features/`)

Thin screens; logic in Riverpod controllers over the repositories + the three
engines.

- **`features/budgets`** — per-category monthly/weekly limit editing, `kind`
  toggle, and status cards (safe/near/over via colour + text + icon, §10.4); the
  standalone variable-budget and safety-buffer editors.
- **Home (`features/home`)** — new cards: **daily safe limit** (today's remaining,
  spent vs limit, overspend detail with offending categories §11.5) and **weekly
  safe limit** (§11.6). Undistributed card already exists (SP1) and now reflects
  real allocations.
- **Allocation flow (`features/allocation`)** — after an income is saved
  (extending SP1's income-entry stub), the §7.2 choice: **allocate now**
  (prefilled from the template, editable), **later** (leaves it undistributed), or
  **apply template as-is**. "Now" opens the §8.4 confirm screen (per-direction
  amounts editable, totals + undistributed + free-balance-after shown). A separate
  template editor manages the reorderable directions (§8.3).

### 7.1 Reactivity / dynamic recalc (§11.3)
Reuse SP1's `ledgerRevisionProvider` bump-on-mutate pattern. Every §11.3 trigger —
new/edited/deleted expense, new income, income allocated, budget changed — bumps
the revision; the safe-limit and budget-status providers `watch` it and recompute
in memory (10k rows = a few ms; SQL aggregation deferred, YAGNI). Goal-funding and
mandatory-payment triggers arrive with SP3/SP4.

## 8. Testing & acceptance

Matches SP1 conventions; run `flutter test --concurrency=1`.

- **`core/limit`** — exhaustive pure tests: normal case, zero/negative remaining,
  over-budget, free-balance cap binding, last-day (days-left = 1), weekly
  aggregation, rollover-by-recompute.
- **`core/allocation`** — each method, ordering, remaining-takes-rest, percentage
  of original income, §8.5 shortfall (partial fund + which underfunded),
  undistributed remainder.
- **`core/budget`** — safe/near(85%)/over thresholds, null limit, deviation sign,
  monthly vs weekly.
- **Repositories** — `NativeDatabase.memory()` fixtures: template reorder,
  allocation-split atomicity + `allocatedMinor` update, budget CRUD.
- **Migration** — v2→v3 success **and** forced-failure recovery (§20.3).
- **Widget/controller** — expense bumps the daily limit (§28.7); allocate-now
  writes split and reduces undistributed; budget status renders text+icon.
- **Acceptance touched** — §28.7 (limit recalcs after every expense), §28.5
  (undistributed), category budget status shown.

## 9. Scope boundary

| In SP2 | Deferred |
|---|---|
| Category budgets (monthly + weekly, status, deviation) | Goal / mortgage buckets → SP3 / SP4 (keys reserved) |
| Daily + weekly safe-limit engine + §11.3 recalc | `toGoal` / `askEachTime` rollover → SP3 |
| Income allocation (fixed / percentage / remaining) + one reusable template | `goalBased` allocation method → SP3 |
| Variable budget + manual safety buffer (settings) | Explicit priority tiers beyond template order → later if needed |
| Mandatory/variable category flag | Subcategories; OS notifications → later |
| Schema v3 migration + §20.3 recovery test | Cross-period budget history / carryover UI → SP5 (Reports) |

## 10. Open questions (deferred, not blocking)

- **Near-limit threshold (85%).** Chosen default; revisit if QA shows it fires too
  early/late. Could later become a setting.
- **Per-period variable-budget storage vs single value.** SP2 stores the current
  period's value with previous-period default. A full per-period budget history
  (for reports/carryover) is an SP5 concern.
- **Free-balance cap across multiple currencies.** SP2 computes the safe limit in
  the primary currency; multi-currency free-balance semantics track the
  Foundation's open multi-currency question (resolved in SP5).
