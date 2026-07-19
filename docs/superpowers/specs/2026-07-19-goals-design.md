# Goals — Design Spec

**Sub-project:** 3 of 7 (Goals)
**Parent product:** Shaxsiy Moliyaviy Assistent (Personal Financial Assistant) — Flutter MVP
**Depends on:** SP0 (Foundation) + SP1 (Accounts & transactions) + SP2 (Allocation & safe-limit engine) — all merged to `master`
**Date:** 2026-07-19
**Status:** Approved for planning

---

## 1. Context

Fourth-built of seven sequential sub-projects. Builds on the Foundation's pure
core (`Money`, `Currency`, `FinancialPeriod`, `Result`), SP1's derived
double-entry ledger + repository/provider pattern + 5-tab shell, and SP2's three
pure engines (`core/allocation`, `core/limit`, `core/budget`) with their generic
string-keyed allocation buckets.

SP3 delivers the seams SP2 deliberately left open for goals:

- **§12** — financial goals: dynamic creation, per-goal data, priorities,
  progress + forecasting, contributions, withdrawals, and completion.
- **§8.2 "Maqsad asosida"** — the `goalBased` allocation method (compute the
  required monthly contribution from a goal's target and deadline).
- **§11.2 `goalReserves`** — the safe-limit engine's goal-reserve input, `0` in
  SP2, now supplied with real values.

Out of scope for SP3 (deferred): §15.5 goal report (SP5 — Reports), §12.5
"contribution from saved category budget" (SP5 — month-close / `savingsRolloverMode`),
real multi-currency goals (SP5).

### Product constraints carried from Foundation / SP1 / SP2 / PRD
- Flutter, iOS + Android, feature parity. Local SQLite only, offline.
- Primary currency UZS; **no FX** in the MVP (§27). Goals are single-currency
  (primary) in SP3; a `// TODO(multi-currency)` guard mirrors SP1/SP2.
- **Correctness of the math is the product** (build-approach memory): all goal
  progress/forecast math lives in a pure `core/goal` engine, no Flutter/Drift
  deps, unit-tested in isolation. Integer minor units only — no float ever.
- Recalculation after every relevant operation; goal reserves recompute into the
  safe limit after every contribution/withdrawal via `ledgerRevisionProvider`.

---

## 2. The central design decision: earmark, not money movement

A goal is an **earmark** over the money already sitting in the user's real
accounts — not a separate account or container. Contributing to a goal does
**not** move money; it records a reservation that reduces the *spendable* free
balance without reducing `totalAvailable`.

This is the model SP2's safe-limit engine was already built for:

```
freeBalance = totalAvailable − minReserve − goalReserves − unpaidMandatory
```

`goalReserves` deducts the earmarked money from what is free to spend while the
money physically stays in accounts. Making goals into real accounts would strand
this seam and double-count (money would leave `totalAvailable` *and* be
subtracted again as `goalReserves`).

**Rationale (and fit to the user's real habit):** the user already physically
separates surplus money (moves it to a savings card, or cashes it out). That
physical movement is already a first-class SP1 **transfer** between real
accounts — the goal feature must not duplicate it. The goal only *labels* part of
the balance as reserved so the safe limit stops treating it as free. A goal can
also be funded from multiple sources over time and from "saved category budget"
money (no real movement at all, §12.5) — an earmark handles all of these; a
money-movement model cannot.

**Optional linked account.** Each goal carries an optional `linkedAccountId`
(e.g. "Jamg'arma karta"). It is metadata only: it lets a user who physically
parks money on a savings card associate the goal with that account for later
reconciliation. Leaving it null makes the goal reserve float over the total
balance. No engine behaviour depends on it in SP3.

**Tradeoff (documented):** because the money stays in one pool, "reserved" money
can still be spent accidentally — the app only warns via the reduced safe limit.
Users who want hard separation do it themselves (their existing habit); the app
tracks the intent rather than enforcing it.

---

## 3. Architecture: derived saved amount + one pure engine

Continues SP1/SP2's principle — everything is **derived**, nothing denormalized.

- A goal's **current saved amount is not stored**. It is
  `Σ signed goal_contributions.amountMinor` (contributions positive, withdrawals
  negative). Single source of truth: the `goal_contributions` table.
- A goal's **auto-allocation rule is not stored separately**. It is expressed as
  ordinary `allocation_directions` rows whose `bucketKey = "goal:{id}"` (SP2's
  generic bucket model, reused with zero schema change to allocation).
- One new pure engine, **`core/goal`**, owns all progress and forecast math.
- `goalReserves` fed to the safe limit reads from `goal_contributions`
  (Σ saved of non-closed goals) — **not** from SP2's `income_allocations` — so
  reserves are never double-counted.

> **Note on `AllocationRepository.reservedTotals()`:** SP2 added it as a
> forward-read intended to feed `goalReserves`. SP3 instead makes
> `goal_contributions` the single source of truth for saved/reserve, so
> `reservedTotals()` is **not** consumed by the goal reserve. It remains for
> SP4 (mortgage `unpaidMandatory`) or later review; do not treat its presence as
> the reserve source.

---

## 4. Data model — Schema v4

`v3 → v4` `onUpgrade`: `createTable` for the two new tables; any future
`addColumn` guarded by the existing `_hasColumn` PRAGMA check. A collapsed
`v1 → v4` pass builds all tables from the current classes (SP2 pattern).

### 4.1 `goals` table
| Column | Type | Notes |
|---|---|---|
| id | int PK autoincrement | |
| name | text | §12.2 |
| type | text | goal type tag (sayohat/avto/zaxira/…); free-form, not a closed enum |
| icon | text, default `flag` | §12.2 |
| targetAmountMinor | int | §12.2 target amount; **must be > 0** |
| currencyCode | text, default `UZS` | primary currency in SP3 |
| startDate | dateTime | §12.2 |
| targetDate | dateTime **nullable** | §12.2; null = no deadline (e.g. emergency reserve) |
| priority | text | `critical` \| `high` \| `medium` \| `low` (§12.3) |
| status | text, default `active` | `active` \| `completed` \| `closed` \| `archived` (§12.7) |
| linkedAccountId | int nullable → accounts.id | optional earmark-backing account (§2) |
| note | text nullable | §12.2 |
| sortOrder | int, default 0 | |
| createdAt | dateTime | |

Current saved amount is **derived** (§3), not a column. Auto-allocation rule is
**derived** from `allocation_directions` with `bucketKey = "goal:{id}"`.

### 4.2 `goal_contributions` table (contribution + withdrawal history, §12.5/§12.6)
| Column | Type | Notes |
|---|---|---|
| id | int PK autoincrement | |
| goalId | int → goals.id | |
| amountMinor | int **signed** | `+` contribution, `−` withdrawal (§12.6) |
| currencyCode | text | |
| source | text | `manual` \| `incomeAllocation` (future: `categorySavings`) |
| sourceAccountId | int nullable → accounts.id | "boshqa hisobdan" source tag (§12.5) |
| incomeTransactionId | int nullable → transactions.id | set when `source=incomeAllocation` |
| note | text nullable | |
| occurredAt | dateTime | history timestamp (§12.5) |
| createdAt | dateTime | |

---

## 5. Pure engine: `core/goal`

Pure Dart, no Flutter/Drift. Integer minor units only. This is the testable
heart of the sub-project.

### 5.1 `GoalProgress` (§12.4 fields)
```
saved, target, remaining = max(0, target − saved)
percentBp        = target > 0 ? clamp(saved · 10000 ÷ target, 0, 10000) : 10000
daysToTargetDate = targetDate == null ? null : days(asOf → targetDate)
projectedDate    = projected completion at current rate (§5.2)
requiredMonthly  = monthly amount to hit target on time (§5.3)
onTrack          = (targetDate != null && projectedDate != null)
                     ? projectedDate ≤ targetDate : null
```

### 5.2 Projected completion date (§12.4 "joriy sur'atda targetga yetish sanasi")
Average-rate extrapolation from the goal's start:
```
elapsedDays  = max(1, days(startDate → asOf))
saved == 0   → projectedDate = null            ("no rate yet")
otherwise    → projectedDaysLeft = remaining × elapsedDays ÷ saved   (integer)
               projectedDate = asOf + projectedDaysLeft
remaining == 0 → projectedDate = asOf          (already complete)
```

### 5.3 Required monthly contribution (§12.4 + §8.2 "Maqsad asosida")
```
targetDate == null → null                      (no deadline)
monthsRemaining    = max(1, (targetDate.year·12 + targetDate.month)
                            − (asOf.year·12 + asOf.month)
                            + (targetDate.day > asOf.day ? 1 : 0))
requiredMonthly    = ceilDiv(remaining, monthsRemaining)
remaining == 0     → 0
```
A **single function** serves both the goal card's "required monthly" figure and
the `goalBased` allocation method (§6.1). A past `targetDate` yields
`monthsRemaining = 1` (fund fully next period).

---

## 6. Allocation & safe-limit integration

### 6.1 `goalBased` allocation method (§8.2) — no engine change
- Add `goalBased` to the `AllocationMethod` enum (currently deferred).
- **Resolved in the provider layer**, before `computeAllocation` runs: a
  direction with `bucketKey = "goal:{id}"` and `method = goalBased` is rewritten
  to a `fixedAmount` equal to `requiredMonthly(goal)` (§5.3). The pure
  `computeAllocation` engine is **untouched** (SP2's tested logic stands). A
  `goalBased` direction that somehow reaches the engine unresolved contributes 0.

### 6.2 Income → contribution bridge
When an income allocation is confirmed (SP2 §8.4 confirm sheet), each
`goal:{id}` bucket amount is also written as a `goal_contributions` row
(`source = incomeAllocation`, `incomeTransactionId` linked), atomically with the
existing `income_allocations` write.

### 6.3 Priority & insufficient income (§8.3 / §8.5) — reuse template order
Goal `priority` is a **display + sort hint**, not a separate engine pass. Goal
directions sit in the single allocation template, ordered by the user (SP2's
reorderable editor). Because `computeAllocation` funds directions in template
order and records `Shortfall`s for anything it cannot fully fund, "§8.5 Critical
first, low priority reduced" is satisfied by **placing** higher-priority goal
directions earlier. No new shortfall mechanism is built.

### 6.4 Safe-limit wiring (§11.2)
`safeLimitProvider` sets `goalReserves = Σ saved of goals whose status is
active or completed` (from `goal_contributions`). `closed`/`archived` goals
release their reserve. One line changes; the `dailySafeLimit` engine is
untouched.

---

## 7. Data / provider layer

**`GoalRepository` (Drift):**
- `list({includeArchived})`, `create`, `update`, `archive`, `delete` (hard).
- `addContribution(goalId, signedAmount, source, {sourceAccountId, incomeTxId, note, occurredAt})`
  — atomic; bumps `ledgerRevisionProvider` after write.
- `contributions(goalId)` — history (§12.5), newest first.
- `savedFor(goalId)` / `savedTotals()` — `Σ signed amountMinor` (derived saved).
- `activeReserve(currency)` — Σ saved of active+completed goals, for `goalReserves`.

**Providers** (all `watch` `ledgerRevisionProvider`; mutators bump it — SP1/SP2 pattern):
- `goalsProvider` → `List<GoalWithProgress>` (repo rows + `core/goal` engine).
- `goalProvider(id)`, `goalContributionsProvider(id)`.
- Goal reserve folded into `safeLimitProvider` (§6.4).
- `resolveGoalDirections` step in the allocation provider (§6.1): `goalBased` →
  `fixedAmount` before `computeAllocation`.

---

## 8. UI (features/goals) — fills the existing "Goal" tab

The 5-tab shell already has a "Goal" tab (`Icons.flag_outlined`, index 3),
currently a placeholder. SP3 replaces the placeholder — no new tab.

- **Goal list:** cards ordered by `sortOrder`/priority. Each card shows §12.4:
  saved/target, progress bar, percent, remaining, time to target, projected date,
  required monthly, priority badge, icon.
- **Create/Edit sheet (§12.2):** name, type, icon, target amount, start date,
  target date (optional), priority, linked account (optional), note.
- **Contribute sheet (§12.5):** amount, source (`manual` / from-account tag →
  account picker), note. **Money fields seeded with `Money.formatNumber()`**
  (SP2 data-loss lesson — never `.format()`).
- **Withdraw sheet (§12.6):** amount (recorded as a negative contribution), note;
  shows impact on the projected/target date.
- **Completion (§12.7):** when a contribution brings saved ≥ target, the goal
  moves to `completed`, a celebration dialog appears, and offers the next action:
  close goal / set a new target / move surplus to another goal.
- **Goal detail:** contribution + withdrawal history list, full progress.
- **Home:** no dedicated goals widget in SP3 (YAGNI) — the safe limit already
  reflects reserves. Can be added later.

---

## 9. Edge cases, validation & error handling

- **Contribution** amount must be `> 0`; **withdrawal** may not exceed current
  saved (guard → user-facing failure, no silent clamp).
- **targetDate in the past** → `monthsRemaining = 1` (§5.3). Does not break.
- **saved == 0** → `projectedDate = null` ("no rate yet" shown).
- **target == 0** → rejected at create (target must be `> 0`).
- **Multi-currency:** MVP is single-currency; a goal whose currency ≠ primary is
  guarded with `// TODO(multi-currency)` (deferred to SP5), matching SP1/SP2.
- **Delete a goal:** default is **soft-archive** (`status = archived`; history
  kept; reserve released). A separate hard-delete removes the goal and its
  contributions.
- **Linked account archived** → the goal keeps working (link is metadata only).
- **Completion detection** runs after every contribution write; withdrawal that
  drops saved back below target returns the goal to `active`.

---

## 10. Testing strategy (TDD)

- **Pure engine (`core/goal`):** `GoalProgress` (percent, remaining,
  `projectedDate` across rates incl. saved=0 and remaining=0, `onTrack`),
  `requiredMonthly` (deadline present/absent, past date, remaining=0),
  `goalBased → fixedAmount` resolution.
- **Repository (no running app):** CRUD; derived saved from signed
  contributions; withdrawal reduces saved; `activeReserve`; withdrawal-exceeds-
  saved guard.
- **Migration:** `v3 → v4` `onUpgrade` creates both tables; collapsed `v1 → v4`.
- **Provider:** `goalReserves` reduces the safe limit; income allocation writes a
  `goal_contributions` row; completion status transition (and reversal on
  withdrawal).
- **Widget:** goal card figures; contribute/withdraw sheets;
  **`formatNumber` seed regression guard** (SP2 data-loss).

---

## 11. Deferred to later sub-projects
- §15.5 goal report + report filtering by goal → **SP5** (Reports).
- §12.5 contribution from saved category budget (`savingsRolloverMode = toGoal`)
  → **SP5** (month-close supplies the savings figure).
- Real multi-currency goals → **SP5**.
- Home goals summary widget → optional, later.
